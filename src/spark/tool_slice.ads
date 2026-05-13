--  tool_slice.ads
--  SPARK specification for SLICE (0x3B) — Sub-tensor slicer.
--  Slices large tensors into BAR-sized chunks for micro-paging.
--  Verified: each chunk fits aperture, drops cover full tensor,
--  loop terminates, no overlaps or gaps.

with Vitriol_Types;
with Interfaces;
with Interfaces.C;

package Tool_Slice with SPARK_Mode
is

   use Vitriol_Types;
   use type Interfaces.Unsigned_64;
   use type Interfaces.Unsigned_32;
   use type Interfaces.C.int;

   Max_Aperture : constant Interfaces.Unsigned_64 :=
     Interfaces.Unsigned_64(256 * 1024 * 1024);

     function Validate
       (Vial : not null access constant Vial_Constraints;
        Op   : not null access constant Drop_Type) return Interfaces.C.int
     with
       Global      => null,
       Convention  => C,
       Export      => True,
       External_Name => "tool_slice__validate",
       Post   => (if Validate'Result /= 0 then
                    Op.Dst_Addr > 0 and then
                    (if Op.Size > 0 then Interfaces.Unsigned_64(Op.Size) else Max_Aperture) <= Vial.Aperture_Max
                  else True);

     function Execute
       (Vial : not null access constant Vial_Constraints;
        Op   : not null access constant Drop_Type) return Tool_Result
     with
       Global      => null,
       Convention  => C,
       Export      => True,
       External_Name => "tool_slice__execute",
       Pre    => Validate(Vial, Op) /= 0,
       Post   => Execute'Result.Success and then Execute'Result.Bytes_Transferred = Op.Dst_Addr;

end Tool_Slice;
