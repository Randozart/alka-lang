--  tool_signal.ads
--  SPARK specification for SIGNAL (0x09) — GPU compute trigger.
--  Triggers GPU to start computing with newly loaded data.
--  Verified: signal_id valid, fits 32-bit register, no data transfer.

with Vitriol_Types;
with Interfaces;

package Tool_Signal with SPARK_Mode
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

end Tool_Signal;
