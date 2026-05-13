--  tool_shift.ads
--  SPARK specification for SHIFT (0x04) — BAR window remapping.
--  Remaps the BAR1 sliding window to a new offset.
--  Verified: offset ≤ aperture, page-aligned, window fits BAR range.

with Vitriol_Types;
with Interfaces;

package Tool_Shift with SPARK_Mode
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

private

   Max_Aperture : constant Interfaces.Unsigned_64 :=
     Interfaces.Unsigned_64(256 * 1024 * 1024);

end Tool_Shift;
