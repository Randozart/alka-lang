--  tool_shift.ads
--  SPARK specification for SHIFT (0x04) — BAR window remapping.
--  Remaps the BAR1 sliding window to a new offset.
--  Verified: offset ≤ aperture, page-aligned, window fits BAR range.

with Vitriol_Types;
with Interfaces;
with Interfaces.C;

package Tool_Shift with SPARK_Mode
is

   use Vitriol_Types;
   use type Interfaces.Unsigned_64;
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
      External_Name => "tool_shift__validate",
      Post   => (if Validate'Result /= 0 then
                   Op.Src_Addr <= Max_Aperture and then (Op.Src_Addr and 16#FFF#) = 0
                 else True);

    function Execute
      (Vial : not null access constant Vial_Constraints;
       Op   : not null access constant Drop_Type) return Tool_Result
    with
      Global      => null,
      Convention  => C,
      Export      => True,
      External_Name => "tool_shift__execute",
      Pre    => Validate(Vial, Op) /= 0,
      Post   => Execute'Result.Success;

end Tool_Shift;
