(* Js_of_ocaml example
 * http://www.ocsigen.org/js_of_ocaml/
 * Copyright (C) 2010 Dmitry Kosarev
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

module Html = Dom_html

let (>>=) = Lwt.bind

exception Break of bool

let is_visible_text s = 
  (* TODO: rewrite with regexps. *)
  let len = String.length s in
  let rec loop i =
    if i >= len then () else 
    if (s.[i] = '\\') && (i<len-1) && (s.[i+1]='\\') then loop (i+2)
    else match  s.[i] with
	| '\n' -> loop (i+1)
	| _   -> raise (Break true)	  
  in 
  try 
    loop 0;
    false
  with Break b -> b

open Dom

let rec html2wiki ?inH:(inH=false) body = 
  let ans = Buffer.create 10 in
  let add_str ?surr:(surr="") s = 
    if is_visible_text s then Buffer.add_string ans (surr^s^surr)
    else () in
  let chNodes = body##childNodes in
  
  for i=0 to chNodes##length - 1 do
    let node = chNodes##item (i) in 
    Js.Optdef.iter node (fun node ->
      match Js.to_string node##nodeName with
	| "B" -> let inner = html2wiki node in
		 add_str inner ~surr:"**"
	| "I" -> let inner = html2wiki node in
		 add_str inner ~surr:"//"
	| "#text" -> (match Js.Opt.to_option  node##nodeValue with
			 | Some x -> Buffer.add_string ans (Js.to_string x)
			 | None	-> ())
	| "P" -> let inner = html2wiki node in
		 add_str (inner ^ "\n\n")
	| "BR"  -> Buffer.add_string ans "\\\\"
	| "HR"  -> Buffer.add_string ans "----"
	| "DIV" -> let inner = html2wiki node in
		   Buffer.add_string ans inner

	| ("H1" | "H2" | "H3") as hh ->
	  let n = int_of_char hh.[1] - (int_of_char '0') + 1 in
	  let prefix = String.make n '=' in
	  let inner = html2wiki node in
	  Buffer.add_string ans (prefix^inner^"\n\n")
	| _ as name -> 
	  Buffer.add_string ans ("^"^ name^"^")
(*	  let ans2 = html2wiki node in
	  Buffer.add_string ans (" |"^ans2^"| ") *)
    )
  done;
  Buffer.contents ans

let onload _ =
  let d = Html.document in
  let body =
    Js.Opt.get (d##getElementById (Js.string "wiki_demo"))
      (fun () -> assert false) in

  let iframe = Html.createIframe d in
  iframe##style##border <- Js.string "2px green solid";
  iframe##src <- Js.string "#";
  iframe##id  <- Js.string "wysiFrame";
  Dom.appendChild body iframe;

  Js.Opt.iter (iframe##contentDocument) (fun iDoc ->
    iDoc##open_ ();
    iDoc##write (Js.string "<html><body><p><b>Camelus</b><i>bactrianus</i></p></body></html>");
    iDoc##close ();
    iDoc##designMode <- Js.string "On";

    let iWin  = iframe##contentWindow in
    Dom.appendChild body (Html.createBr d);

    (* see http://www.quirksmode.org/dom/execCommand.html 
     * http://www.mozilla.org/editor/midas-spec.html
     *)
    let createButton ?show:(show=Js._false) ?value:(value=None) title action = 
      let but = Html.createInput ?_type:(Some (Js.string "submit")) d in
      but##value <- Js.string title;
      let wrap s = match s with
	| None -> Js.null | Some s -> Js.some (Js.string s) in
      
      but##onclick <- Html.handler 
	(fun _ -> 
	  iWin##focus ();
	  iDoc##execCommand (Js.string action, show, wrap value); 
	  Js._true);
      Dom.appendChild body but
    in

    createButton "hr" "inserthorizontalrule";
    createButton "remove format" "removeformat";
    createButton "B" "bold";
    createButton "I" "italic";
    Dom.appendChild body (Html.createBr d);
    createButton "p" "formatblock" ~value:(Some "p");
    createButton "h1" "formatblock" ~value:(Some "h1");
    createButton "h2" "formatblock" ~value:(Some "h2");
    createButton "h3" "formatblock" ~value:(Some "h3");

    Dom.appendChild body (Html.createBr d);

    let preview = Html.createTextarea d in
    preview##readOnly <- Js._true;
    preview##cols <- 34;
    preview##rows <- 10;
    preview##style##border <- Js.string "1px black solid";
    preview##style##padding <- Js.string "5px";
    Dom.appendChild body preview;

    let wikiFrame = Html.createTextarea d in
    wikiFrame##id <- Js.string "wikiFrame";
    wikiFrame##readOnly <- Js._true;
    wikiFrame##cols <- 34;
    wikiFrame##rows <- 10;
    preview##style##border <- Js.string "2px blue solid";
    preview##style##padding <- Js.string "5px";
    Dom.appendChild body wikiFrame;

    let rec dyn_preview old_text n =
      let text = Js.to_string iDoc##body##innerHTML in
      let n =
	if text <> old_text then begin
	  begin try
		  preview##value <- Js.string text;
		  wikiFrame##value <- Js.string (html2wiki (iDoc##body :> Dom.node Js.t) )
	    with _ -> () end;
	  20
	end else
	  max 0 (n - 1)
      in
      Lwt_js.sleep (if n = 0 then 0.5 else 0.1) >>= fun () ->
      dyn_preview text n
    in
    ignore (dyn_preview "" 0)
  );
  Js._false

let _ = Html.window##onload <- Html.handler onload
