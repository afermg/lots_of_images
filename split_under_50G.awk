# The input file is obtained using 'find data -mindepth 2 -maxdepth 2 -exec du -m {} + | sort -k2 > files.txt'
BEGIN {i=-1};
{if ($2 ~ /Acq.txt/) # Use the acquisition file as separator
    {
	i++; size=$1; meta[i]=$2; meta_size=$1;
    }
    else {
	{
	    if ($2 ~ /.txt/) { # Fill up metadata array
		meta[i]=meta[i]" "$2;
		meta_size += $1;
	    }
	    else {
		if ($1+size<50000) { # Concatenate contents array
		    content[i]=content[i]" "$2;
		    size += $1;
		}
		else
		{ # Extend contend and add the new files
		    meta[i+1]=meta[i];
		    content[i+1]=$2;
		    size = $1 + meta_size;
		    i++;
		}}}}}
END {
    # print [meta files]" "[content files] on one line per set of files
    for (i=0;i<length(meta);i++) print meta[i]" "content[i];
}
