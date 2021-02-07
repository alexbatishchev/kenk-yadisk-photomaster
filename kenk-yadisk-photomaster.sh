#!/bin/bash

####### экспортируем фотки из Photo в оригинальном качестве и с записью xmp

# перегоняем хейки в jpg c хитрой обработкой профиля чтобы вне мака цвета были похожие№
# https://apple.stackexchange.com/questions/297134/how-to-convert-a-heif-heic-image-to-jpeg-in-el-capitan
# https://legacy.imagemagick.org/discourse-server/viewtopic.php?t=34268
# https://github.com/ImageMagick/ImageMagick/issues/1486
# в два прохода, переводим в sRGB и применяем цветовой профиль sRGB. Эппл показывает и так, сторонние программы (типа XNView даже под мак) начинают показывать хорошо, не просирая насыщенность цветов
# In bash, you can set the nullglob option so that a pattern that matches nothing "disappears", rather than treated as a literal string:
shopt -s nullglob

# converting heic to temp jpg files
for i in ./data/*.heic
do 
echo "converting to jpeg heic file $i"
convert "$i" "$i.jpg"
done
# converting temp jpeg to result jpeg with sRGB color profile and gamma correction
for i in ./data/*.heic.jpg 
do 
echo "converting color profile in $i to $i.jpg"
convert "$i" -colorspace sRGB -profile DCI-P3-D65.icc -gamma 1.0 -colorspace sRGB -profile sRGB.icc "$i.jpg" 
done

#renaming resulting files, cleaning up source and temp data
for i in ./data/*.heic.jpg.jpg
do 
f=$(basename "$i")
echo $f
f2="${f%.*}"
f3="${f2%.*}"
f4="${f3%.*}"
f5="./data/$f4.jpg"
f6="./data/$f4.heic.jpg"
f7="./data/$f4.heic"

echo renaming temp jpeg-from-heic $i to final $f5
mv "$i" "$f5"
echo deleting temp file "$f6" and original heic "$f7"
rm "$f6"
rm "$f7"
done


#now going to folder with pictures to process tags and rename
cd data

#dirty hack: png with set datetimeoriginal renaming before importing xmp, to get yandex-friendly tags
exiftool -v '-Filename<${datetimeoriginal}.%f.%e' -d "%Y-%m-%d %H-%M-%S" *.png -directory=out -if '($datetimeoriginal and (not ($datetimeoriginal eq "0000:00:00 00:00:00")))'


# далее пробиваем параметры из xmp в графические файлы
find . -maxdepth 1  -not -iname "*.xmp" -exec bash -c 'file="{}"; xmpname=${file%.*}.xmp; echo "$xmpname"; echo "$file"; exiftool -tagsfromfile "$xmpname" -xmp "$file" -overwrite_original' \;

# пробиваем атрибуты и переименовываем файлы по дате в зависимости от типа и содержимого

# video
exiftool '-FileModifyDate<TrackCreateDate' '-FileName<TrackCreateDate' -d "%Y-%m-%d %H-%M-%S.%%f.%%e" *.mov -directory=out
exiftool '-FileModifyDate<TrackCreateDate' '-FileName<TrackCreateDate' -d "%Y-%m-%d %H-%M-%S.%%f.%%e" *.mp4 -directory=out

## JPEGS
# renaming jpegs where already set datetimeoriginal (most valuable for yandex etc)
exiftool -v '-Filename<${datetimeoriginal}.%f.%e' -d "%Y-%m-%d %H-%M-%S" *.jpg -directory=out -if '($datetimeoriginal and (not ($datetimeoriginal eq "0000:00:00 00:00:00"))) and ($filetype eq "JPEG")' 
exiftool -v '-Filename<${datetimeoriginal}.%f.%e' -d "%Y-%m-%d %H-%M-%S" *.jpeg -directory=out -if '($datetimeoriginal and (not ($datetimeoriginal eq "0000:00:00 00:00:00"))) and ($filetype eq "JPEG")' 
#copying datetimeoriginal from DateCreated where it possible and renaming second time after that
exiftool -v '-datetimeoriginal<$DateCreated' *.jpeg -if '($DateCreated and (not ($DateCreated eq "0000:00:00 00:00:00"))) and ($filetype eq "JPEG")' -overwrite_original
exiftool -v '-datetimeoriginal<$DateCreated' *.jpg -if '($DateCreated and (not ($DateCreated eq "0000:00:00 00:00:00"))) and ($filetype eq "JPEG")' -overwrite_original
exiftool -v '-Filename<${datetimeoriginal}.%f.%e' -d "%Y-%m-%d %H-%M-%S" *.jpg -directory=out -if '($datetimeoriginal and (not ($datetimeoriginal eq "0000:00:00 00:00:00"))) and ($filetype eq "JPEG")' 
exiftool -v '-Filename<${datetimeoriginal}.%f.%e' -d "%Y-%m-%d %H-%M-%S" *.jpeg -directory=out -if '($datetimeoriginal and (not ($datetimeoriginal eq "0000:00:00 00:00:00"))) and ($filetype eq "JPEG")' 

#now PNGs left after first renaming and xmp importing
exiftool -v '-Filename<${datetimeoriginal}.%f.%e' -d "%Y-%m-%d %H-%M-%S" *.png -directory=out -if '($datetimeoriginal and (not ($datetimeoriginal eq "0000:00:00 00:00:00")))'
exiftool -v '-datetimeoriginal<$DateCreated' *.png -if '($DateCreated and (not ($DateCreated eq "0000:00:00 00:00:00")))'  -overwrite_original
exiftool -v '-Filename<${datetimeoriginal}.%f.%e' -d "%Y-%m-%d %H-%M-%S" *.png -directory=out -if '($datetimeoriginal and (not ($datetimeoriginal eq "0000:00:00 00:00:00")))'

# GIFs
exiftool -v '-Filename<${datetimeoriginal}.%f.%e' -d "%Y-%m-%d %H-%M-%S" *.gif -directory=out -if '($datetimeoriginal and (not ($datetimeoriginal eq "0000:00:00 00:00:00"))) and ($filetype eq "GIF")' 
exiftool -v '-datetimeoriginal<$DateCreated' *.gif -if '($DateCreated and (not ($DateCreated eq "0000:00:00 00:00:00")))'  -overwrite_original
exiftool -v '-Filename<${datetimeoriginal}.%f.%e' -d "%Y-%m-%d %H-%M-%S" *.gif -directory=out -if '($datetimeoriginal and (not ($datetimeoriginal eq "0000:00:00 00:00:00"))) and ($filetype eq "GIF")' 

# Чистим xmp
rm -f ./*.xmp

# перекладываем файлы в папки YYYY/YYYY-MM/
cd out
echo "sorting by date to folders..."
find . -maxdepth 1  -type f -exec bash -c 'file=$(basename "{}"); yearname=${file:0:4}; monthname=${file:5:2}; pathname="$yearname/$yearname-$monthname"; mkdir -p "$pathname"; mv "$file" "$pathname"/ ' \;
