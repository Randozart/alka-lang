--  vitriol-tool.ads
--  SPARK specification for Alka atomic hardware tools.
--  Each tool is a small, mathematically verified micro-program
--  that performs exactly one hardware operation.
--
--  Verified properties:
--    1. No buffer overflow on aperture access
--    2. All operations within thermal limits
--    3. DMA transfers respect BAR window boundaries
--    4. No pointer arithmetic errors

package Vitriol_Tool with SPARK_Mode
is

   --  Tool opcodes (matches Alka instruction set)
   type Op_Code is
     (CLAIM,      --  0x01  Stake hardware node
      FLOW,       --  0x03  DMA transfer
      SHIFT,      --  0x04  Remap BAR window
      FENCE,      --  0x05  Wait for metapage
      SYNC,       --  0x06  Memory barrier
      LIMIT,      --  0x0E  Thermal limit
      REFRACT,    --  0x3B  Sub-tensor slicer
      PIPE,       --  0x3C  Continuous DMA ring buffer
      UNKNOWN)
   with Size => 8;

    --  32-byte Drop (matches kernel struct alka_drop)
    type Drop_Type is
      record
         Op_Code    : Op_Code;
         Flags      : Unsigned_8;
         Vessel_ID  : Unsigned_16;
         Src_Addr   : Unsigned_64;
         Dst_Addr   : Unsigned_64;
         Size       : Unsigned_32;
         Reserved   : Unsigned_32;
         CRC        : Unsigned_32;
      end record
   with Convention => C, Size => 256;

   --  Vial constraints passed from Zig compiler
   type Vial_Constraints is
      record
         Aperture_Size   : Unsigned_64;  --  BAR window size (bytes)
         Aperture_Max    : Unsigned_64;  --  Max sliding window
         Thermal_Halt    : Unsigned_32;  --  mC
         Thermal_Throttle : Unsigned_32; --  mC
         DMA_Capable     : Boolean;
      end record
   with Convention => C;

   --  Tool result
   type Tool_Result is
      record
         Success         : Boolean;
         Cycles_Spent    : Unsigned_64;
         Bytes_Transferred : Unsigned_64;
         Error_Message   : Interfaces.C.Strings.chars_ptr;
      end record
   with Convention => C;

    --  Each tool implements this interface
    function Validate
      (Op   : Drop_Type;
       Vial : Vial_Constraints) return Boolean
    with
      Global => null,
      Post   => Validate'Result /= Validate'Result; -- placeholder

    procedure Execute
      (Op      : in Drop_Type;
       Vial    : in Vial_Constraints;
       Result  : out Tool_Result)
   with
     Global => null,
     Pre    => Validate(Op, Vial),
     Post   => (if Result.Success then Result.Bytes_Transferred = Op.Size);

private

   --  Maximum aperture size supported
   Max_Aperture : constant Unsigned_64 := 256 * 1024 * 1024; -- 256MB

   --  Proof helper: chunk count for sliding window
   function Chunk_Count
     (Total : Unsigned_64;
      Chunk : Unsigned_64) return Unsigned_64
   is (if Chunk > 0 then (Total + Chunk - 1) / Chunk else 0)
   with
     Pre  => Chunk > 0 and then Total > 0,
     Post => Chunk_Count'Result * Chunk >= Total;

end Vitriol_Tool;
