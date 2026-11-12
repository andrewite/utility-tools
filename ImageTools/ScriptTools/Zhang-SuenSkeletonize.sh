#!/bin/bash

#This tool is for the embedding system with insufficient memory .

##https://sci-hub.hkvisa.net/10.1145/357994.358023
## T. Y. Zhang, Department of Computer Science and Automatic Control, Chongqing University, Chongqing, China;
##C. Y. Suen, Department of Computer Science, Concordia University,1455 de Maisonneuve West, Montreal, Quebec H3G 1M8. Canada


 WhiteValueCount_Awk='function WhiteValueCount(  COUNT,i){COUNT=0;for(i=4;i<=11;i++)if($i)COUNT++;return COUNT;}'
 BlackValueCount_Awk='function BlackValueCount(  COUNT,i){COUNT=0;for(i=4;i<=11;i++)if(!$i)COUNT++;return COUNT;}'
 ChangeCountFrom0to1_Awk='function SpokesCountFrom0to1(  COUNT,i,last){COUNT=0;last=$11;for(i=4;i<=11;i++){if((!last)&&($i))COUNT++;last=$i;}return COUNT;}'


# $1 :X   $2: Y
## P9  P2  P3           $11  $4  $5  
## P8  P1  P4    <==>   $10  $3  $6 
## P7  P6  P5           $9   $8  $7 

ZhangSuenCheck_Awk()
{
  local ProcessingStepIndex=$1
  awk -v ProcessingStepIndex=$ProcessingStepIndex "$BlackValueCount_Awk $WhiteValueCount_Awk $ChangeCountFrom0to1_Awk"'{fB_Count=BlackValueCount();    cond_cd=0;
    if((ProcessingStepIndex%2==1)&&  ($4*$6*$8==0)&&($6*$8*$10==0)) cond_cd=1;
    else if((ProcessingStepIndex%2==0)&&  ($4*$6*$10==0)&&($4*$8*$10==0)) cond_cd=1;
    if($3&&(fB_Count>=2)&&(fB_Count<=6)&&(cond_cd)&&(SpokesCountFrom0to1()==1))$3=0;  print $0 }'
}


ImgDataToXYP1P2P3P4P5P6P7P8P9()  # to X Y  P(P1)  and around: P2 P3 ...
{
   ##Result will be:  X  Y  P  P2 P3 P4 P5 P6 P7 P8 P9 

  awk 'function CopyMem3ToMem2_2to1(nr){for(i=1;i<=NF+2;i++){m1[i]=m2[i];m2[i]=m3[i];}}
      function SaveCurrentToMem3(nr){for(i=1;i<=NF+2;i++){
          if((nr>0)&&(i>1)&&(i<NF+2))m3[i]=$(i-1);else m3[i]=0;}}
      function PrintAroundValue(nr){for(i=2;i<=NF+1;i++){
          print i-1,nr,m2[i], m1[i],m1[i+1],m2[i+1],m3[i+1],m3[i],m3[i-1],m2[i-1],m1[i-1];}}
   BEGIN{SaveCurrentToMem3(0);CopyMem3ToMem2_2to1();CopyMem3ToMem2_2to1();}
      {CopyMem3ToMem2_2to1();SaveCurrentToMem3(NR);if(NR>1)PrintAroundValue(NR-1); }
   END{CopyMem3ToMem2_2to1();SaveCurrentToMem3(0);PrintAroundValue(NR); }' 
}


Zhang_Suen_Method_Awk()
{
   local ImgWidth=$1

   local ProcessStepIndex=$ProcessCount   ### start from 1 

    ImgDataToXYP1P2P3P4P5P6P7P8P9 | 
    ZhangSuenCheck_Awk $ProcessStepIndex |
    TIP="print progress" awk '{print $0;if(($1==1)&&($2%100==1))system("echo "$2" >&2 ")}'   |
    awk -v ImgWidth=$ImgWidth '{printf("%d ", $3);if(NR%ImgWidth==0)print "";}' 

}

Zhang_Suen_Method_Awk__Loop()
{
   #using this method, the intermiddle result is  NOT  visible

  local ImgWidth=$1

  local tmp1=$(mktemp /tmp/Zhang_SuenXXXXX)
  local tmp2=$(mktemp /tmp/Zhang_SuenXXXXX)
  cat > $tmp1
  local ProcessCount=1 
  while :; do

    echo == ProcessCount=$ProcessCount == >&2
    
    cat $tmp1 | Zhang_Suen_Method_Awk $ImgWidth >  $tmp2 
    if diff -q $tmp1  $tmp2 > /dev/null  ;then break;fi
    mv $tmp2 $tmp1
    
    ProcessCount=$(($ProcessCount+1)) 
  done
  cat $tmp1
  rm $tmp1 $tmp2
}

GetBMPColorBitNum()
{
   local FILE="$1"
   tail -c+$((1+0x1c)) "$FILE" | od -vAn -tu2 -w2 |head -1
}

PrintBMPImgData()
{
   local BMPColorBitNum=$1
   local ImgWidth=$2 
   local WhiteGate="${WhiteGate-128}"
   
   if [ "$BMPColorBitNum" = "24" ] ;then
    awk -v WhiteGate=$WhiteGate '{for(i=1;i+2<=NF;i+=3){v=$i+$(i+1)+$(i+2);if(v>WhiteGate*3)v=1;else v=0; printf("%d ",v)}print ""; }' 
   elif [ "$BMPColorBitNum" = "1" ] ;then
     awk -v ImgWidth=$ImgWidth '
     function ToBinary(x,maxBits  ,s,i){for(i=1;i<=8;i++)if(i<=maxBits){s=x%2 " " s;x=x/2-(x/2%1);}return s}
     {for(i=1;i<=NF;i++){printf("%s",ToBinary($i,ImgWidth-8*(i-1)));}print "";  } ' 
   fi
}

RestoreImgDataToBMP()
{
   local BMPColorBitNum=$1
   local ImgWidth=$2 
   if [ "$BMPColorBitNum" = "24" ] ;then
     awk '{for(i=1;i<=NF;i++){v=$i;if(v>1)v=1;v*=255;printf("%02x %02x %02x ",v,v,v);}; i=(3*NF)%4;if(i)while(i++<4)printf(" 00");print "" ; }'
   elif [ "$BMPColorBitNum" = "1" ] ;then
     local ImgDataWidth=$(( (($ImgWidth*$BMPColorBitNum+31)/32)*4 ))
     awk -v ImgWidth=$ImgWidth  -v ImgDataWidth=$ImgDataWidth '{for(i=1;i<=ImgDataWidth*8;i++){if(i%8==1)v=0;v=v*2; if(i<=ImgWidth)v+=$i;if(i%8==0)printf("%02x ",v);}; print "" ; }'
   fi
}

ProcessBMPImgDataUsingXX()
{
  local DataProcessMethod="$1"
  local FILE="$2"
  local OUTFILE="$3"
  
 (
 local ImgDateOffset=$(tail -c+3 "$FILE" | od -vAn -tu4 -w4| sed -n "3s/ *//p")
 local Width=$(tail -c+3 "$FILE" | od -vAn -tu4 -w4| sed -n "5s/ *//p")
 local BMPColorBitNum=$(GetBMPColorBitNum "$FILE" )
 local ImgDataWidth=$(( (($Width*$BMPColorBitNum+31)/32)*4 ))

 cat "$FILE"  | head -c +$ImgDateOffset ;
 cat "$FILE"  | tail -c +$((1+$ImgDateOffset)) | od -tu1 -vAn -w$ImgDataWidth  |
    PrintBMPImgData      $BMPColorBitNum $Width  |
    $DataProcessMethod      $Width               |
    RestoreImgDataToBMP  $BMPColorBitNum $Width  | xxd -r -ps ) > "$OUTFILE"

}

BMP_Skeletonize_Main()
{
  #in every loop, the intermiddle result is visible
  
  local FILE="$1"
  local ResultFILE="$2"

  local tmp1=$(mktemp /tmp/Zhang_SuenXXXXX)

  local InFILE="$1"
  local OutFILE="$ResultFILE"

  local ProcessCount=1 #Important!! must from 1 , it is used in  Zhang_Suen_Method_Awk
  while [ "$ProcessCount" -lt 10000 ] ; do
  
    ProcessBMPImgDataUsingXX Zhang_Suen_Method_Awk "$InFILE" "$OutFILE"
    if diff -q "$InFILE" "$OutFILE" > /dev/null ;then break; fi

    InFILE=$OutFILE
    #Output to ResultFILE asap for users to preview the result
    if [ "$OutFILE" == "$ResultFILE" ] ;then OutFILE=$tmp1; else OutFILE="$ResultFILE" ;fi
    ProcessCount=$(($ProcessCount+1)) 
    echo ProcessCount=$ProcessCount >&2

  done
   if [ "$OutFILE" != "$ResultFILE" ] ;then mv "$OutFILE" "$ResultFILE" ;fi
   [ -e "$tmp1" ] && rm "$tmp1"
}

if [ "$1" == "RUN" ] ;then shift;$@;exit;fi


FILE="$1"  OUTFILE="$2"

if [ -z "$FILE" ] || [ -z "$OUTFILE" ] ;then 
 echo USAGE: $0 Input.24bit.bmp OutputFileMame.bmp ;
 echo "    you can use convert(or mogrify) XXX.jpg(or png)   -alpha off  <-negate>  XXX.bmp to get it."
 exit; 
fi
  BMPColorBitNum=$(GetBMPColorBitNum "$FILE" )
if [ "$(head -c 2 "$FILE" )" != "BM" ]  || 
   ( [ $BMPColorBitNum != 24 ] && [ $BMPColorBitNum != 1 ] ) ;then 
 echo Only bmp files in 24bits or 1bit format are supported. ;
 exit; 
fi


#    ProcessBMPImgDataUsingXX Zhang_Suen_Method_Awk__Loop  "$FILE" "$OUTFILE"

BMP_Skeletonize_Main "$FILE" "$OUTFILE"  #the result of every step is visible using this method


