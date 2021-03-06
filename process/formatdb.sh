# ! /bin/bash
#
# How to call it in a bank.properties file ?
#
# formatdb.type=index
# formatdb.name=formatdbAll
# formatdb.args="fasta/All/all_n.fasta" "blast/All/" "-p F -o T" "all_n"
# formatdb.exe=formatdb.sh
# formatdb.cluster=
# formatdb.desc=Index blast
#
# Script for Biomaj PostProcess
# author : ofilangi
# date   : 19/06/2007
# update : 22/10/2010 fix bug in generated alias file + a few cleanups
#
#  -t  Title for database file [String]  Optional
#  -i  Input file(s) for formatting [File In]  Optional
#  -l  Logfile name: [File Out]  Optional
#    default = formatdb.log
#  -p  Type of file
#         T - protein
#         F - nucleotide [T/F]  Optional
#    default = T
#  -o  Parse options
#         T - True: Parse SeqId and create indexes.
#         F - False: Do not parse SeqId. Do not create indexes.
# [T/F]  Optional
#    default = F
#  -a  Input file is database in ASN.1 format (otherwise FASTA is expected)
#         T - True,
#         F - False.
# [T/F]  Optional
#    default = F
#  -b  ASN.1 database in binary mode
#         T - binary,
#         F - text mode.
# [T/F]  Optional
#    default = F
#  -e  Input is a Seq-entry [T/F]  Optional
#    default = F
#  -n  Base name for BLAST files [String]  Optional
#  -v  Database volume size in millions of letters [Integer]  Optional
#    default = 4000
#  -s  Create indexes limited only to accessions - sparse [T/F]  Optional
#    default = F
#  -V  Verbose: check for non-unique string ids in the database [T/F]  Optional
#    default = F
#  -L  Create an alias file with this name
#        use the gifile arg (below) if set to calculate db size
#        use the BLAST db specified with -i (above) [File Out]  Optional
#  -F  Gifile (file containing list of gi's) [File In]  Optional
#  -B  Binary Gifile produced from the Gifile specified above [File Out]  Optional
#  -T  Taxid file to set the taxonomy ids in ASN.1 deflines [File In]  Optional
#
#

#----------
#GLOBAL DEF
#----------

BLASTDB_DIR="/db/index-blast"; # Path where aliases files should be generated
FORMATDB=/usr/bin/formatdb; # Path to formatdb executable


#----------
# FUNCTIONS 
#----------
# createAlias: builds an alias file
# arg1: file to write to
# arg2: bank name
# arg3: db file list
createAlias() {
  local file=$1;
  local nomBanque=$2;
  local lFiles=$3;

  rm -f $file;
  echo "#" > $file
  echo "# Alias file created "`date` >>$file 
  echo "#" >>$file ;
  echo "#">> $file ;
  echo "TITLE "$nomBanque >> $file; 
  echo "#" >> $file;
  echo "DBLIST "$lFiles >>$file;
  echo "#" >> $file;
  echo "#GILIST" >> $file;
  echo "#" >> $file;
  echo "#OIDLIST" >> $file;
  echo "#" >> $file;
}

#-----
# MAIN
#-----

if (test $# -ne 4) then
  echo "arguments:" 1>&2
  echo "1: input files"
  echo "2: working directory" 1>&2
  echo "3: formatdb options (without -i for input file)" 1>&2
  echo "4: bank name" 1>&2
  echo `formatdb --help`;
  exit -1
fi

relWorkDir=`echo "$2" | sed "s/\/*$//"` # remove useless trailing slash

workdir=$datadir/$dirversion/future_release
workdir=$workdir/$relWorkDir;

rm -rf $workdir;
mkdir -p $workdir ;

if ( test $? -ne 0 ) then
  echo "Cannot create $workdir." 1>&2 ;
  exit 1;
fi

cd $workdir

# Some vars for links creation
back="";
dir=$relWorkDir;
OLDIFS=$IFS;
IFS="/";
for i in $dir
do
  back="../"$back;
done
IFS=$OLDIFS;

# Create links to input files into the working dir
listFile="";

for expression in $1
do
  # the basename can be a regex
  lsFile=`ls $datadir/$dirversion/future_release/$expression`;
  if ( test $? -ne 0 ) then
    echo "No input file found in dir `pwd`." 1>&2 ;
    exit 1
  fi
  baseFile=`dirname $expression`;
  for f in $lsFile
  do
    name=`basename $f`;
    rm -f $4.p*;
    rm -f $4.n*;
    nameLink=`echo $name | cut -d"." -f1`;
    ln -s $back/$baseFile/$name $nameLink;
    if ( test $? -ne 0 ) then
      echo "Cannot create link. [ln -s $back$f $name]" 1>&2 ;
      exit 1
    fi
    if (test -z "$listFile") then
      listFile=$nameLink;
    else
      listFile=$nameLink" "$listFile;
    fi
  done
done

echo "Input sequence file list: $listFile";

if (test -z "$listFile") then
  echo "No input file found." 1>&2 ;
  exit 1
fi

nameB=$4;
echo "Database name: $nameB";

echo "Working in "`pwd`;
echo "Launching formatdb [formatdb -i $listFile $3 -n $nameB]";

# Execute formatdb
$FORMATDB -i "$listFile" $3 -n $nameB;

formatdbResult=$?
if ( test $formatdbResult -ne 0 ) then
  echo "Formatdb failed with status $formatdbResult" 1>&2 ;
  exit 1
fi

echo "##BIOMAJ#blast###$2/$nameB"

# Delete temp files and links
#-------------------------------------------------------------
rm -f $listFile;
rm -f formatdb.log

# Add generated files to biomaj postprocess dependance
echo "Generated files:";
for ff in `ls *`
do
  echo $PP_DEPENDENCE$PWD/$ff;
done

goodPath=`readlink $datadir/$dirversion/future_release -s -n`;
if ( test $? -ne 0 ) then
  echo "Failed to get version path: readlink returned with an error [$goodPath]" 1>&2 ;
  exit 1
fi

# Search for nal files which are sometimes generated by formatdb.
lsAl=`ls *.?al 2> /dev/null`;

if ( test $? -ne 0 ) then
  echo "No alias file found.";
  lsAl="";
else
  echo "Generated alias files:"
  echo "$lsAl";
fi

# If nal files were generated, use them to generate nal files in $BLASTDB_DIR
for fileIndexVirtuel in $lsAl 
do
  echo "Found alias file: [$fileIndexVirtuel]";
  listIndex=`more $fileIndexVirtuel | grep DBLIST`;
  listFile2="";
  for f in $listIndex
  do
    if (test $f != "DBLIST") then
      listFile2=$goodPath/$relWorkDir/$f" "$listFile2;
    fi
  done
  echo "Creating alias in [$BLASTDB_DIR/$fileIndexVirtuel]";
  createAlias $BLASTDB_DIR/$fileIndexVirtuel $nameB "$listFile2"
done

# Else, if no nal file was generated by formatdb, create them
if (test -z "$lsAl") then
  ext=`ls | grep .*hr$ | tail -c5 | head -c2`al;
  echo "Creating alias file [$PWD/$4$ext]";
  
  listNhr=`ls *.*hr | sed 's/\..hr$//g'`;
  listFileNalRel=""; # List of blast db files, relative path
  listFileNalAbs=""; # List of blast db files, absolute path
  for f in $listNhr
  do
    listFileNalRel=$f" "$listFileNalRel;
    listFileNalAbs=$goodPath/$relWorkDir/$f" "$listFileNalAbs;
  done

  createAlias $4$ext $nameB "$listFileNalRel";
  echo $PP_DEPENDENCE$PWD/$4$ext;
  
  echo "Creating alias in [$BLASTDB_DIR/$4$ext]";
  createAlias $BLASTDB_DIR/$4$ext $nameB "$listFileNalAbs" ;
fi

