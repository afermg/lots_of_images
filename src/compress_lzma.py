import lzma
from pathlib import Path

import numpy as np
import zarr
from imagecodecs.numcodecs import Brotli
from numcodecs import Blosc, LZMA

z1s = np.array(
    [
        zarr.convenience.load(path)
        for path in list(
            Path(
                "data/19311_2020_10_23_downUpshift_2_0_2_glu_dual_phluorin__glt1_psa1_ura7__twice__04/"
            ).glob("phluorin_glt1_*1.zarr")
        )
    ]
)

# z1 = np.load("test.npy")
filters = [
    dict(id=lzma.FILTER_DELTA, dist=9),
    dict(id=lzma.FILTER_LZMA2, preset=9),
    # dict(id=lzma.FILTER_DELTA, dist=2),
    # dict(id=lzma.FILTER_LZMA2, preset=9),
]
compression = {
               "lz4hc":{"clevel":9},
               "zstd": {"clevel":9},
    }


compressors=[Blosc(cname=k, shuffle=-1, **v) for k,v in compression.items()]

imagecodecs_compressors = [
    # Delta(shape=test.shape, dtype=test.dtype, axis=1, dist=5),
    Brotli(level=11),
]
                            
compressors += [LZMA(**v) for v in {"preset":{"preset":9},
                                             "filters":{"filters":filters, "format":lzma.FORMAT_RAW}}.values()]

compressors += imagecodecs_compressors

def compress_data(data, compressor, chunks):
    compressed = zarr.array(data,
                            compressor = compressor,
                            chunks=chunks)
    print(compressed.info)
    
    return compressed

for compressor in compressors:
    compress_data(z1s, compressor, chunks=(1, 192, 1, 1, *z1s.shape[-2:]))


# %%
# from pathos.multiprocessing import Pool

# with Pool() as p:
#     compressed = p.map(lambda x: compress_data(test, x), )
