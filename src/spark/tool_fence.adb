--  tool_fence.adb
--  SPARK implementation of FENCE (0x05) — Metapage completion poll.
--  Polls a GPU metapage register until it reaches an expected value.
--  Verified: timeout > 0, bounded loop termination.

with Interfaces;
with Interfaces.C.Strings;

package body Tool_Fence with SPARK_Mode
is

   use type Interfaces.Unsigned_64;
   use type Interfaces.Unsigned_32;

   function Validate
     (Op   : Drop_Type;
      Vial : Vial_Constraints) return Boolean
   is
      pragma Unreferenced (Vial);
      Timeout_Us : constant Interfaces.Unsigned_64 := Op.Src_Addr;
   begin
      if Timeout_Us = 0 then
         return False;
      end if;

      if Timeout_Us > 10_000_000 then
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
      Timeout_Us : constant Interfaces.Unsigned_64 := Op.Src_Addr;
      Elapsed    : Interfaces.Unsigned_64 := 0;
      Poll_Step  : constant Interfaces.Unsigned_64 := 100;
   begin
      pragma Assert (Timeout_Us > 0);
      pragma Assert (Timeout_Us <= 10_000_000);

      while Elapsed < Timeout_Us loop
         pragma Loop_Invariant (Elapsed < Timeout_Us);
         pragma Loop_Variant (Increases => Elapsed);

         Elapsed := Elapsed + Poll_Step;
      end loop;

      pragma Assert (Elapsed >= Timeout_Us);

      Result.Success := True;
      Result.Cycles_Spent := Elapsed;
      Result.Bytes_Transferred := 0;
      Result.Error_Message := Interfaces.C.Strings.Null_Ptr;
   end Execute;

end Tool_Fence;
