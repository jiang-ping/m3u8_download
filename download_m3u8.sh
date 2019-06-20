#!/bin/sh

# resolve full url
fullurl() {
	url="$1"
	baseurl="$2"

	if echo "$url" | grep -v "http" > /dev/null; then
		# not a full url, but a path
		url="`dirname ${baseurl}`/${url}"	
	fi

	echo "$url"
}

# download m3u8/ts file
download() {
	tofile="$2"
	baseurl="$3"
	url=`fullurl "$1" "$baseurl"`
	
	echo "Download $url -> $tofile" | tee -a download.log
	curl "$url" > "$tofile" 2>>download.log
	if [ "$?" -ne 0 ]; then
		echo "failed, diagnosis information:"
		curl -s -o /dev/null  -Lv "$url"
	fi
}

# download M3U8
downidx() {
	indexName="$1"
	url="$2"
	baseurl="$3"
	tofile="$indexName.m3u8"

	# download the playlist
	download "$url" "$tofile" "$baseurl"
	idx=`cat $tofile`

	# generate local m3u8
	echo "$idx" | awk -F'#' '
		NF==1 {
			if($0~/m3u8/) {
				print IN NR ".m3u8"
			} else {
				print "ts/" IN "-" NR ".ts"
			}
		} 
		NF>1{print;}' IN=$indexName > "$tofile"	

	# recursively download playlist
	cmd=`echo "$idx" | awk -F'#' '
		NF==1 {
			if($0~/m3u8/) {
				printf("downidx %s \"%s\" \"%s\"\n", IN NR, $0, baseurl)
			} else {
				printf("download \"%s\" %s \"%s\"\n", $0 , "ts/" IN "-" NR ".ts", baseurl)}
			}
		' IN=$indexName baseurl="$baseurl"`
	eval "$cmd"
}


if [ -z "$1" ] || [ -z "$2" ]; then
	echo "Usage: $0 <m3u8URL> <localDir>"
else
	mkdir -p "$2"/ts
	cd "$2"
	downidx "idx" "$1" "$1"
fi
