{ The EGA ports, and the register indices and values the Pascal code writes through them: the Graphics Controller (GC_)
  and the Sequencer (SEQ_). }
unit C_Ega;

interface

const
  { the EGA Graphics Controller's index port, and GC_DATA_PORT its data port; Blit, TextRend }
  GC_ADDR_PORT = $3CE;
  GC_DATA_PORT = $3CF;
  { the EGA Sequencer's index port, and SEQ_DATA_PORT its data port; Blit, TextRend }
  SEQ_ADDR_PORT = $3C4;
  SEQ_DATA_PORT = $3C5;
  { EGA register indices and values Blit and TextRend both write through those ports, named after the EGA's registers }
  { the Graphics Controller's Read Map Select register: the plane a read returns }
  GC_READ_MAP_REG = 4;
  { the Graphics Controller's Mode register, which picks the write mode }
  GC_MODE_REG = 5;
  { Mode register value: write mode 0 (read mode 0), CPU data to the planes, the default }
  GC_WRITE_MODE_0 = 0;
  { the Sequencer's Map Mask register: the planes a write reaches }
  SEQ_MAP_MASK_REG = 2;
  { Map Mask value: every plane writable }
  MAP_MASK_ALL_PLANES = $F;

implementation

end.
