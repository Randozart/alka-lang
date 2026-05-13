--  vitriol_types.ads
--  Shared types for Alka SPARK tools.
--  Each tool package imports this spec for the common type definitions.

with Interfaces.C;
with Interfaces.C.Strings;

package Vitriol_Types with SPARK_Mode
is

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;

   --  Tool opcodes (matches Alka instruction set)
   type Op_Code is
     (CLAIM,      --  0x01  Stake hardware node
      FLOW,       --  0x03  DMA transfer
      SHIFT,      --  0x04  Remap BAR window
      FENCE,      --  0x05  Wait for metapage
      SYNC,       --  0x06  Memory barrier
      SIGNAL,     --  0x09  GPU compute trigger
      LIMIT,      --  0x0E  Thermal limit
      REFRACT,    --  0x3B  Sub-tensor slicer
      PIPE,       --  0x3C  Continuous DMA ring buffer
      UNKNOWN)
   with Size => 8;

   --  32-byte Drop (matches kernel struct alka_drop)
   type Drop_Type is
      record
         Op_Kind    : Op_Code;
         Flags      : Interfaces.Unsigned_8;
         Vessel_ID  : Interfaces.Unsigned_16;
         Src_Addr   : Interfaces.Unsigned_64;
         Dst_Addr   : Interfaces.Unsigned_64;
         Size       : Interfaces.Unsigned_32;
         Reserved   : Interfaces.Unsigned_32;
         CRC        : Interfaces.Unsigned_32;
      end record
   with Convention => C, Pack;

   --  Vial constraints passed from Zig compiler
   type Vial_Constraints is
      record
         Aperture_Size    : Interfaces.Unsigned_64;
         Aperture_Max     : Interfaces.Unsigned_64;
         Thermal_Halt     : Interfaces.Unsigned_32;
         Thermal_Throttle : Interfaces.Unsigned_32;
         DMA_Capable      : Boolean;
      end record
   with Convention => C;

   --  Tool result
   type Tool_Result is
      record
         Success            : Boolean;
         Cycles_Spent       : Interfaces.Unsigned_64;
         Bytes_Transferred  : Interfaces.Unsigned_64;
         Error_Message      : Interfaces.C.Strings.chars_ptr;
      end record
   with Convention => C;

   --  Proof helper: chunk count for sliding window
   function Chunk_Count
     (Total : Interfaces.Unsigned_64;
      Chunk : Interfaces.Unsigned_64) return Interfaces.Unsigned_64
   is (if Chunk > 0 then (Total + Chunk - 1) / Chunk
       else Interfaces.Unsigned_64(0))
   with
     Pre  => Chunk > 0 and then Total > 0,
     Post => Chunk_Count'Result * Chunk >= Total;

end Vitriol_Types;
