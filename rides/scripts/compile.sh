help="Usage: `basename $0` [options] -- Compiles images for rides
	-h			Echos this help text
	-d			Delete images in renderout folder after compiling
	-r 1|2|3	Enables 1, 2, or 3 re-mappable colors
	-c			Only composites images, i.e. if images have already been palettized
"

delete=false
rem=false
palettize=true

# Get command line flags
while getopts ":hdcr:" option; do
	case "$option" in
		h)
			echo "$help"
			exit
			;;
		d)
			delete=true
			;;
		c)
			palettize=false
			;;
		r)
			nrem=$OPTARG
			if [ "$nrem" != '1' ] && [ "$nrem" != '2' ] && [ "$nrem" != '3' ]; then
				echo "Invalid argument for -r" >&2
				echo "$help" >&2
				exit 1
			fi
			rem="true"
 			;;
		\?)
			printf "illegal option: -%s\n" "$OPTARG" >&2
			echo "$help" >&2
			exit 1
			;;
		:)
			echo "Must provide argument for -r" >&2
			echo "$help" >&2
			exit 1
			;;
	esac
done

# Create finished directory if not exist
mkdir "finished" 2>/dev/null

if [ $palettize == "true" ]; then

	echo "Palettizing images..."


	if [ "$rem" == "true" ]; then
		# No need to palettize the remap, since this is now done in Blender
		#convert "renderout/remap*.png"  +dither -remap "../../../templates/paletteremap$nrem.png" "renderout/remap%05d.png"
		convert "renderout/img*.png" +dither -remap "../../../templates/paletteforremap$nrem.png" "renderout/img%05d.png"
	else
		convert "renderout/img*.png" -dither none -remap "../../../templates/palette.png" BMP3:"finished/pic%05d.bmp"
	fi

fi

echo "Compositing images..."

if [ "$rem" == "true" ]; then
	for f in renderout/img*.png ; do 
		g=${f:13:5}		# Extract digits from string
		
		
		# Composite and trim images
		case $g in
			# Icon image
			0)
				composite "renderout/img$g.png" "renderout/remap$g.png" "finished/pic$g.ppm"
				convert -gravity Center -crop 112x112+0+0 +repage +dither -remap "../../../templates/palette.png" "finished/pic$g.ppm" "finished/pic$g.ppm"
				echo "0,0" > finished/pos.txt
				;;
			# Generate 2 Blank images
			1)
				;&
			2)
				convert canvas:"#23532b" "finished/pic$g.ppm"
				echo "0,0" >> finished/pos.txt
				;;
			# Actual ride images
			*)
				composite "renderout/img$g.png" "renderout/remap$g.png" "finished/pic$g.ppm"
				canvastex=$(convert "finished/pic$g.ppm" -trim -print '%X%Y' -quiet "finished/pic$g.ppm")
				missed=${canvastex:0:1} # Catch missed (i.e. empty) images
				if [ $missed == "-" ]; then
					posx=0
					posy=0
				else
					canvastex=${canvastex:1}
					IFS=+ read x y <<< "$canvastex"
					posx=$(expr 128 - $x)
					posy=$(expr 128 - $y)
				fi
				echo "-${posx},-${posy}" >> finished/pos.txt
				;;
		esac

		ppmtobmp "finished/pic$g.ppm" -bpp 8 -quiet > "finished/pic$((10#$g)).bmp"		#$(()) converts to integer, to get rid of zero padding
		rm "finished/pic$g.ppm"
		
	done
else
	for f in finished/pic*.bmp ; do 
		g=${f:12:5}
		
		# Trim images
		case $g in
			# Icon Image
			00000)
				mogrify -gravity Center -crop 112x112+0+0 +repage -colors 256 "finished/pic$g.ppm"
				echo "0,0" >> finished/pos.txt
				;;
			# Generate 2 Blank images
			00001)
				;&
			00002)
				convert canvas:"#23532b" "finished/pic$g.bmp"
				echo "0,0" >> finished/pos.txt
				;;
			# Actual ride images
			*)
				canvastex=$(mogrify -trim -print '%X%Y' -colors 256 "finished/pic$g.ppm" -quiet)
				missed=${canvastex:0:1} # Catch missed (i.e. empty) images
				if [ $missed == "-" ]; then
					posx=0
					posy=0
				else
					canvastex=${canvastex:1}
					IFS=+ read x y <<< "$canvastex"
					posx=$(expr 128 - $x)
					posy=$(expr 128 - $y)
				fi
				echo "-${posx},-${posy}" >> finished/pos.txt
				;;
		esac
		
		# Convert ppm to 8-bit BMP
		ppmtobmp "finished/pic$g.ppm" -bpp 8 -quiet > "finished/pic$((10#$g)).bmp"		#$(()) converts to integer, to get rid of zero padding
		rm "finished/pic$g.ppm"
		
	done
fi

	
	# Cleanup if -d is set

if [ "$delete" == "true" ]; then
	echo "Cleaning up..."

	for f in renderout/*.png; do 
		rm $f
	done
fi


echo "Done"