(* Js_of_ocaml tests
 * http://www.ocsigen.org/js_of_ocaml/
 * Copyright (C) 2019 Ty Overby
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*)

open Util
module J = Js_of_ocaml_compiler.Javascript

let print_var_decl program n =
  let {var_decls; _} =
    find_javascript
      ~var_decl:(function
        | J.S {name; _}, _ when name = n -> true
        | _ -> false)
      program
  in
  print_string (Format.sprintf "var %s = " n);
  match var_decls with
  | [(_, Some (expression, _))] -> print_string (expression_to_string expression)
  | _ -> print_endline "not found"

let%expect_test _ =
  let cmo =
    compile_ocaml_to_bytecode
      {|
    let lr = ref (List.init 2 Obj.repr)
    let black_box v = lr := (Obj.repr v) :: !lr

    type r = {x: int; y: string}

    let ex = {x = 5; y = "hello"} ;;
    black_box ex
    let ax = [|1;2;3;4|] ;;
    black_box ax
    let bx = [|1.0;2.0;3.0;4.0|] ;;
    black_box bx ;;

    (* combined with the black_box function above, this
       will prevent the ocaml compiler from optimizing
       away the constructions. *)
    print_int ((List.length !lr) + (List.length !lr))
  |}
  in
  let program = parse_js (print_compiled_js ~pretty:true cmo) in
  print_var_decl program "ex";
  print_var_decl program "ax";
  print_var_decl program "bx";
  [%expect
    {|
    var ex = [0,5,caml_new_string("hello")];
    var ax = [0,1,2,3,4];
    var bx = [254,1,2,3,4]; |}]
