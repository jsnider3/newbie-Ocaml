open Core.Std;;
open Printf;;

type input =
  {
   pos_in : unit -> int;
   seek_in : int -> unit;
   input_char : unit -> char;
   input_byte : unit -> int;
   input_char_opt : unit -> char option;
   length : int
  };;

(*
  Page 26: Question 1 
*)
let input_of_chars chs = let pos = ref 0 in
  {
    pos_in = (fun() -> !pos);
    seek_in = (fun p ->
                if p < 0
                  then raise(Invalid_argument "Can't do that");
                pos := p);
    input_char = (fun () ->
                  (if !pos = (List.length chs)
                      then raise End_of_file;
                   pos := (!pos + 1);
                   List.nth_exn chs (!pos - 1);
                  )
                 );
    input_char_opt = (fun () ->
                   pos := (!pos + 1);
                   List.nth chs (!pos - 1);
                 );
    input_byte = (fun () ->
                   pos := (!pos + 1);
                   match List.nth chs (!pos - 1) with
                    Some x -> Char.to_int x
                    |None -> -1;
                 );
    length = List.length chs;
  };;

(*
  Page 26: Question 2
*)
let rec input_string inp len = match len with
  0 -> ""
  |_ ->   try (let c = String.of_char (inp.input_char()) in
            c ^ input_string inp (len - 1)) with
            _ -> "";;

(*
  Page 26: Question 3
*)
let int64_to_int n = match Int64.to_int n with
  Some x -> x
  |None -> raise(Invalid_argument "not a number?");;

let input_of_channel ch =
  { 
   pos_in = (fun () -> int64_to_int (In_channel.pos ch));
   seek_in = (fun n -> In_channel.seek ch (Int64.of_int n));
   input_char = (fun () -> input_char ch);
   input_char_opt = (fun () -> In_channel.input_char ch);
   input_byte = (fun () -> match In_channel.input_char ch with
                                Some x -> Char.to_int x
                                |None -> -1);
   length = int64_to_int (In_channel.length ch)
  };;

let input_of_string ch = let pos = ref 0 in
  {
   pos_in = (fun () -> !pos);
   seek_in = (fun p -> if p < 0 then
                          raise (Invalid_argument "seek before start");
                        pos := p);
   input_char = (fun () -> if !pos > (String.length ch - 1)
                             then raise End_of_file
                             else (let c = ch.[!pos] in 
                                  pos := 1 + !pos; c));
   input_char_opt = (fun () -> if !pos > (String.length ch - 1)
                             then None
                             else (let c = ch.[!pos] in 
                                  pos := 1 + !pos; Some c));

   input_byte = (fun () -> if !pos > (String.length ch - 1)
                             then -1
                             else (let c = ch.[!pos] in 
                                  pos := 1 + !pos; Char.to_int c));
   length = String.length ch
  };;

(*
  Page 26: Question 5
*)
let line_reader ch = {ch with
   input_char = (fun () -> match ch.input_char () with
                            '\n' -> raise End_of_file
                            |x -> x;);
   input_char_opt = (fun () -> match ch.input_char_opt () with
                             Some '\n' -> None
                             |x -> x);

   input_byte = (fun () -> match ch.input_byte () with
                            10 -> raise End_of_file
                            |x -> x);
  (*
    Length field for this is invalid. 
  *)
  };;

(*
  Page 26: Question 5
*)
type output =
  {
    output_char : char -> unit;
    out_channel_length : unit -> int;
  };;

let output_of_channel ch = 
  {
    output_char = (fun c -> output_char ch c);
    out_channel_length = (fun () -> int64_to_int (Out_channel.length ch));
  };;

let output_of_buffer bf = 
  {
    output_char = (fun c -> Buffer.add_char bf c);
    out_channel_length = (fun () -> Buffer.length bf);
  };;

(* Start of chapter 5. *)

type input_bits =
  {
    input : input;
    mutable byte : int;
    mutable bit : int;
  };;

let bool_to_int b = if b then 1 else 0;;

(* My version of align. *)
let loadbyte b =
  b.byte <- int_of_char (b.input.input_char ());
  b.bit <- 128;;

let nextbit b = let ind = b.bit in
  b.bit <- b.bit / 2;
  b.byte land (ind) > 0;;

let rec getbit b =
  match b.bit with
    0 -> loadbyte b; getbit b
    |_ -> nextbit b;;

(* Not tail recursive, but stack depth is bounded. 
   Could be done with a fold? *)
let rec getval b n = assert (n > 0 && n < 32);
  match n with
    1 -> bool_to_int (getbit b);
    |_ -> (bool_to_int (getbit b)) + (getval b (n - 1) lsl 1);;

(*
  Page 34 Question 2
*)
let rec getval_32 b n = Int32.of_int_exn (getval b n);;

type output_bits =
  {
    output : output;
    mutable byte : int;
    mutable bit : int;
  };;

let output_bits_of_output out =
  {
    output = out;
    byte = 0;
    bit = 7;
  };;

let flush o =
  if o.bit < 7 then o.output.output_char (char_of_int o.byte);
  o.byte <- 0;
  o.bit <- 7;;

let rec putbit o b = match o.bit with
  -1 -> flush o; putbit o b;
  |_ -> o.byte <- o.byte lor (b lsl o.bit);
        o.bit <- o.bit - 1;; 

(*
  Page 34 Question 3
*)
let putbyte o v = o.byte <- v;
  o.bit <- 0;
  flush o;;

let rec putval o v l = 
  if o.bit = 7 && l = 8
    then putbyte o v
  else if l > 0 then
    begin
    let shift = 1 lsl (l - 1) in
    putbit o (v land shift);
    putval o (v land (lnot shift)) (l - 1)
    end
  ;; 

(*
  Page 34 Question 4
*)
let rec putval_32 o v = putval o (Int32.to_int_exn v) 32;;

(*
  Page 34 Question 5: Modifying a string in-place is deprecated,
                      but could be done by removing the last
                      char in a string whenever you change the byte
                      and don't move to the next one.
*)

(*
  Chapter 6
*)
let string_of_int_list l =
  let s = String.create (List.length l) in
    List.iteri l (fun n x -> s.[n] <- Char.of_int_exn x);
    s;;

let rec str_map_helper str f acc ind = 
  if ind = 0
    then (f str.[0])::acc
    else str_map_helper str f ((f str.[ind])::acc) (ind - 1);;

let string_map str f =
  str_map_helper str f [] ((String.length str) - 1);;

let int_list_of_string l =
  string_map l (Char.to_int);;

(*

*)
let test_input_of_chars () =
  let inp = input_of_chars ['a'; 'b'; 'c'] in
  assert (inp.input_char () = 'a');
  assert (inp.input_char () = 'b');
  assert (inp.input_char () = 'c');
  assert (inp.input_char_opt () = None);
  inp.seek_in 0;
  assert ("abc" = (input_string inp 4));;

let test_input_of_channel () =
  let inp = input_of_channel (open_in "BitIO.ml") in
  assert ("open Core.Std;;" = (input_string inp 15));;

let test_line_reader () =
  let inp = line_reader(input_of_channel (open_in "BitIO.ml")) in
  assert ("open Core.Std;;" = (input_string inp 95));;

let test_getbit () = 
  let bits = {input = input_of_chars ['a']; byte = 188; bit = 128} in
  (* Reading 188 *)
  assert (getbit bits = true);
  assert (getbit bits = false);
  assert (getbit bits = true);
  assert (getbit bits = true);
  assert (getbit bits = true);
  assert (getbit bits = true);
  assert (getbit bits = false);
  assert (getbit bits = false);
  (* Reading 'a' *)
  assert (getbit bits = false);
  assert (getbit bits = true);
  assert (getbit bits = true);
  assert (getbit bits = false);
  assert (getbit bits = false);
  assert (getbit bits = false);
  assert (getbit bits = false);
  assert (getbit bits = true);;

let test_getval () =
  let bits = {input = input_of_chars ['a']; byte = 188; bit = 128} in
  assert ((getval bits 8) = 188);
  assert ((getval bits 8) = 97);;

let test_output () = ();;

let main () = 
  test_input_of_chars ();
  test_input_of_channel ();
  test_line_reader ();
  test_getbit ();
  test_getval ();
  test_output ();
  assert ("ABC" = (string_of_int_list [65;66;67]));;
  assert (int_list_of_string "ABC" = [65;66;67]);;

main ();;
