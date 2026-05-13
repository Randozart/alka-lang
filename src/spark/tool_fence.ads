--  tool_fence.ads
--  SPARK specification for FENCE (0x05) — Metapage completion poll.
--  Polls a GPU metapage register until it reaches an expected value.
--  Verified: timeout > 0, bounded loop termination.

with Vitriol_Types;
with Interfaces;
with Interfaces.C;

package Tool_Fence with SPARK_Mode
is

   use Vitriol_Types;
   use type Interfaces.Unsigned_64;
   use type Interfaces.C.int;

     function Validate
       (Vial : not null access constant Vial_Constraints;
        Op   : not null access constant Drop_Type) return Interfaces.C.int
     with
       Global      => null,
       Convention  => C,
       Export      => True,
       External_Name => "tool_fence__validate",
       Post   => (if Validate'Result /= 0 then
                    Op.Src_Addr > 0 and then Op.Src_Addr <= 10_000_000
                  else True);

     function Execute
       (Vial : not null access constant Vial_Constraints;
        Op   : not null access constant Drop_Type) return Tool_Result
     with
       Global      => null,
       Convention  => C,
       Export      => True,
       External_Name => "tool_fence__execute",
       Pre    => Validate(Vial, Op) /= 0,
       Post   => Execute'Result.Success and then Execute'Result.Bytes_Transferred = 0;

end Tool_Fence;
