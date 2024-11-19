"""
Script to automatically compress all the groups in an experiment
"""
import numpy as np
import zarr
from numcodecs import LZMA, Blosc
from pathlib import Path
path = Path("/home/amunoz/projects/microscopy_backup/data/")
fullpath_prefix = {}
for expt_name in path.glob("[!.]*/"):
    print(expt_name)
    expt_path = Path(expt_name)
    for fpath in expt_path.glob("*.zarr"):
        fpath = Path(fpath)
        fname = fpath.stem
        prefix = "pos"
        if "_" in fname:
            prefix = "_".join(fname.split("_")[:-1])
        fullpath_prefix[str(expt_path / prefix)] = prefix
        
# compressor=Blosc(cname="lz4hc", clevel=9, shuffle=-1)
out_dir = Path("compressed")
out_dir.mkdir(exist_ok=True)

def compress_array(wildcard):
    path= Path(wildcard)
    dir = path.parent
    array = np.array([zarr.convenience.load(fpath) for fpath in sorted(dir.glob(f"{path.name}*.zarr"))])

    recompressed = zarr.array(
        array,
        chunks=(1,20, 1, *array.shape[-3:]),
    compressor=Blosc("zstd", clevel=9, shuffle=-1)
    )
    
    zarr.convenience.save(out_dir / filepath.parent / f"{filepath.stem}.zarr", recompressed)

from time import perf_counter
t = perf_counter()

# for k,f in fullpath_prefix.items():
#     compress_array(k)
#     print(f"{Path(k).name} took {perf_counter()-t}s")

from multiprocessing import Pool, cpu_count

with Pool(3) as pool:
    results = pool.map(compress_array, fullpath_prefix.keys())
    
print(perf_counter()-t)

