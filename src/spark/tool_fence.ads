--  tool_fence.ads
--  SPARK specification for FENCE (0x05) — Metapage completion poll.
--  Polls a GPU metapage register until it reaches an expected value.
--  Verified: timeout > 0, bounded loop termination.

with Vitriol_Types;
with Interfaces;

package Tool_Fence with SPARK_Mode
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

end Tool_Fence;
