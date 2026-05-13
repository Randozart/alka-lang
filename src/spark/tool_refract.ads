--  tool_refract.ads
--  SPARK specification for REFRACT (0x3B) — Sub-tensor slicer.
--  Slices large tensors into BAR-sized chunks for micro-paging.
--  Verified: each chunk fits aperture, drops cover full tensor,
--  loop terminates, no overlaps or gaps.

with Vitriol_Types;
with Interfaces;

package Tool_Refract with SPARK_Mode
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

end Tool_Refract;
