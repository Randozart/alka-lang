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
       (Vial : not null access constant Vial_Constraints;
        Op   : not null access constant Drop_Type) return Interfaces.C.int
    is
       pragma Unreferenced (Vial);
       Signal_ID : constant Interfaces.Unsigned_64 := Op.Src_Addr;
    begin
       if Signal_ID = 0 then
          return 0;
       end if;

       if Signal_ID > 16#FFFF_FFFF# then
          return 0;
       end if;

       return 1;
    end Validate;

     function Execute
       (Vial : not null access constant Vial_Constraints;
        Op   : not null access constant Drop_Type) return Tool_Result
    is
       pragma Unreferenced (Vial);
       Signal_ID : constant Interfaces.Unsigned_64 := Op.Src_Addr;
    begin
       pragma Assert (Signal_ID > 0);
       pragma Assert (Signal_ID <= 16#FFFF_FFFF#);

       return (Success            => True,
               Cycles_Spent       => 50,
               Bytes_Transferred  => 0,
               Error_Message      => Interfaces.C.Strings.Null_Ptr);
    end Execute;

end Tool_Signal;
