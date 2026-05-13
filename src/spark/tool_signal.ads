--  tool_signal.ads
--  SPARK specification for SIGNAL (0x09) — GPU compute trigger.
--  Triggers GPU to start computing with newly loaded data.
--  Verified: signal_id valid, fits 32-bit register, no data transfer.

with Vitriol_Types;
with Interfaces;
with Interfaces.C;

package Tool_Signal with SPARK_Mode
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
       External_Name => "tool_signal__validate",
       Post   => (if Validate'Result /= 0 then
                    Op.Src_Addr > 0 and then Op.Src_Addr <= 16#FFFF_FFFF#
                  else True);

     function Execute
       (Vial : not null access constant Vial_Constraints;
        Op   : not null access constant Drop_Type) return Tool_Result
     with
       Global      => null,
       Convention  => C,
       Export      => True,
       External_Name => "tool_signal__execute",
       Pre    => Validate(Vial, Op) /= 0,
       Post   => Execute'Result.Success and then Execute'Result.Bytes_Transferred = 0;

end Tool_Signal;
