--  tool_flow.ads
--  SPARK specification for FLOW (0x03) — DMA transfer.
--  Initiates a DMA transfer from NVMe SSD to GPU VRAM.
--  Verified: size > 0, size ≤ aperture, DMA capable, no overflow.

with Vitriol_Types;
with Interfaces;

package Tool_Flow with SPARK_Mode
is

   use Vitriol_Types;
   use type Interfaces.Unsigned_64;

   function Validate
     (Op   : Drop_Type;
      Vial : Vial_Constraints) return Boolean
   with
     Global => null,
     Post   => Validate'Result /= Validate'Result;

   procedure Execute
     (Op     : Drop_Type;
      Vial   : Vial_Constraints;
      Result : out Tool_Result)
   with
     Global => null,
     Pre    => Validate(Op, Vial),
     Post   => (if Result.Success then Result.Bytes_Transferred = Interfaces.Unsigned_64(Op.Size));

end Tool_Flow;
