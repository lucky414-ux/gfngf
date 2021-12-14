; RUN: opt -enable-new-pm=0 -load libjulia-codegen%shlibext -LateLowerGCFrame -FinalLowerGC -S %s | FileCheck %s


declare void @boxed_simple({} addrspace(10)*, {} addrspace(10)*)
declare {} addrspace(10)* @jl_box_int64(i64)
declare {}*** @julia.ptls_states()
declare {}*** @julia.get_pgcstack()
declare i32 @sigsetjmp(i8*, i32) returns_twice
declare void @one_arg_boxed({} addrspace(10)*)

define void @try_catch(i64 %a, i64 %b)
{
; Because of the returns_twice function, we need to keep aboxed live everywhere
; CHECK: %gcframe = alloca {} addrspace(10)*, i32 4
top:
    %sigframe = alloca [208 x i8], align 16
    %sigframe.sub = getelementptr inbounds [208 x i8], [208 x i8]* %sigframe, i64 0, i64 0
    call {}*** @julia.get_pgcstack()
    call {}*** @julia.ptls_states()
    %aboxed = call {} addrspace(10)* @jl_box_int64(i64 %a)
    %val = call i32 @sigsetjmp(i8 *%sigframe.sub, i32 0) returns_twice
    %cmp = icmp eq i32 %val, 0
    br i1 %cmp, label %zero, label %not
zero:
    %bboxed = call {} addrspace(10)* @jl_box_int64(i64 %b)
    call void @one_arg_boxed({} addrspace(10)* %bboxed)
    unreachable
not:
    call void @one_arg_boxed({} addrspace(10)* %aboxed)
    ret void
}
