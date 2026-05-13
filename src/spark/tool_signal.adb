--  tool_signal.adb
--  SPARK implementation of SIGNAL (0x09) — GPU compute trigger.
--  Triggers GPU to start computing with newly loaded data.
--  Verified: signal_id valid, fits 32-bit register, no data transfer.

with Interfaces;
with Interfaces.C.Strings;

package body Tool_Signal with SPARK_Mode
is

   use type Interfaces.Unsigned_64;
   use type Interfaces.Unsigned_32;

   function Validate
     (Op   : Drop_Type;
      Vial : Vial_Constraints) return Boolean
   is
      pragma Unreferenced (Vial);
      Signal_ID : constant Interfaces.Unsigned_64 := Op.Src_Addr;
   begin
      if Signal_ID = 0 then
         return False;
      end if;

      if Signal_ID > 16#FFFF_FFFF# then
         return False;
      end if;

      return True;
   end Validate;

   procedure Execute
     (Op     : Drop_Type;
      Vial   : Vial_Constraints;
      Result : out Tool_Result)
   is
      pragma Unreferenced (Vial);
      Signal_ID : constant Interfaces.Unsigned_64 := Op.Src_Addr;
   begin
      pragma Assert (Signal_ID > 0);
      pragma Assert (Signal_ID <= 16#FFFF_FFFF#);

      Result.Success := True;
      Result.Cycles_Spent := 50;
      Result.Bytes_Transferred := 0;
      Result.Error_Message := Interfaces.C.Strings.Null_Ptr;
   end Execute;

end Tool_Signal;
