#!/bin/bash
#
# Script to create md5 hashes for files in and below the current directory
#
# "Inspired" from https://askubuntu.com/questions/990495/update-md5-checksum-when-files-are-modified
#
# or the directory passed at the commandline
# In the first run, create the sums for all files.
# In the second run,
#  - if the files have not changed, keep the entries
#  - if the files have been deleted, forget the entry
#  - if the files have changed, create new md5 hash.
#
# Rough version - should be optimized
#


if [ $# -lt 1 ] ; then
  echo "Usage:"
  echo "$0 <hashfile> [<topdir>]"
  echo
  exit
fi

export HASHFILE=$1
export TOPDIR='secrets'
if [ $# -eq 2 ] ; then TOPDIR=$2; fi

export BACKFILE=$HASHFILE.bck
export TMPFILE=$HASHFILE.tmp

# Function to encrypt files using sops
function encrypt () {
echo "** Setting up environment for encryption..."
if [[ -f $TOPDIRkeys.tar.gz ]]; then
  tar -xzvf $TOPDIR/keys.tar.gz -C $TOPDIR/
  export GNUPGHOME="$TOPDIR/keys"
  export GPG_TTY=$(tty)
  export FP=$( gpg2 --with-colons --fingerprint | awk -F: '$1 == "fpr" {print $10; exit}' )
fi
TO_ENC=$(echo $1 | cut -f 1 -d ".")
echo "***"
sops -e -p $FP --encrypted-suffix='_templates' $1 > ${TO_ENC}.enc.yaml

}


# In the first run, we create the file $HASHFILE if it does not exist
# You have to make sure that $HASHFILE does not contain any garbage for the first run!!

if ! [ -f $HASHFILE] && [ -s $HASHFILE ]; then
  echo -n "* Creating $HASHFILE for the first time..."
  find $TOPDIR -type f -name "*.plain.yml" -not -path './private_keys/*' -print0 | xargs -0 md5sum > $HASHFILE
  echo -e "\n* Done."
  exit
fi

# In the second run, we proceed to find the differences.
# First, find the newer files

find $TOPDIR -type f -name "*.plain.yml" -not -path './private_keys/*' -newer $HASHFILE -print > $TMPFILE

# Now save the old file and create a new one, starting with new files

mv $HASHFILE $BACKFILE
echo -n "* Processing new or modified files..."
cat $TMPFILE | while read filename ; do
  md5sum "$filename" >> $HASHFILE
done
echo -e  "\n* Done."

# Now walk through the old file and process to new file

cat $BACKFILE | while read md5 filename ; do
  # Does the file still exist?
  if [ -f "$filename" ] ; then
    # Has the file been modified?
    if grep -q -e "^$filename$" $TMPFILE ; then 
      echo "* $filename has changed!"
      echo "* Calling sops..."
      encrypt "$filename"
    else
    #   echo "$md5  $filename" >> $HASHFILE
      echo "* $filename has not changed."
    fi
  else
    echo "* $filename has been removed!"
  fi
done

exit