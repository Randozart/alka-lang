--  tool_flow.ads
--  SPARK specification for FLOW (0x03) — DMA transfer.
--  Initiates a DMA transfer from NVMe SSD to GPU VRAM.
--  Verified: size > 0, size ≤ aperture, DMA capable, no overflow.

with Vitriol_Types;
with Interfaces;
with Interfaces.C;

package Tool_Flow with SPARK_Mode
is

   use Vitriol_Types;
   use type Interfaces.Unsigned_64;
   use type Interfaces.Unsigned_32;
   use type Interfaces.C.int;

     function Validate
       (Vial : not null access constant Vial_Constraints;
        Op   : not null access constant Drop_Type) return Interfaces.C.int
     with
       Global      => null,
       Convention  => C,
       Export      => True,
       External_Name => "tool_flow__validate",
       Post   => (if Validate'Result /= 0 then
                    Op.Size > 0 and then
                    Interfaces.Unsigned_64(Op.Size) <= Vial.Aperture_Max and then
                    Vial.DMA_Capable and then
                    Op.Src_Addr + Interfaces.Unsigned_64(Op.Size) >= Op.Src_Addr and then
                    Op.Dst_Addr + Interfaces.Unsigned_64(Op.Size) >= Op.Dst_Addr
                  else True);

     function Execute
       (Vial : not null access constant Vial_Constraints;
        Op   : not null access constant Drop_Type) return Tool_Result
     with
       Global      => null,
       Convention  => C,
       Export      => True,
       External_Name => "tool_flow__execute",
       Pre    => Validate(Vial, Op) /= 0,
       Post   => Execute'Result.Success and then Execute'Result.Bytes_Transferred = Interfaces.Unsigned_64(Op.Size);

end Tool_Flow;
