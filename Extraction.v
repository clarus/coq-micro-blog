Require Import Coq.Lists.List.
Require Import Coq.ZArith.ZArith.
Require Import ExtrOcamlBasic.
Require Import ExtrOcamlBigIntConv.
Require Import ExtrOcamlString.
Require Import ErrorHandlers.All.
Require Import FunctionNinjas.All.
Require Import ListString.All.
Require Import Computation.
Require Http.
Require Import Model.
Require View.

Import ListNotations.

Module String.
  Parameter t : Type.
  Extract Constant t => "string".

  Parameter of_lstring : LString.t -> t.
  Extract Constant of_lstring => "Utils.String.of_lstring".

  Parameter to_lstring : t -> LString.t.
  Extract Constant to_lstring => "Utils.String.to_lstring".
End String.

(** Unbounded integers. *)
Module BigInt.
  (** The OCaml's `bigint` type. *)
  Definition t : Type := bigint.

  (** Export to a `Z`. *)
  Definition to_Z : t -> Z := z_of_bigint.
End BigInt.

Module Lwt.
  Parameter t : Type -> Type.
  Extract Constant t "'a" => "'a Lwt.t".

  Parameter ret : forall {A : Type}, A -> t A.
  Extract Constant ret => "Lwt.return".

  Parameter bind : forall {A B : Type}, t A -> (A -> t B) -> t B.
  Extract Constant bind => "Lwt.bind".

  Parameter run : forall {A : Type}, t A -> A.
  Extract Constant run => "Lwt_main.run".

  Parameter printl : String.t -> t unit.
  Extract Constant printl => "Lwt_io.printl".

  Parameter read_file : String.t -> t (option String.t).
  Extract Constant read_file => "Utils.read_file".

  Parameter update_file : String.t -> String.t -> t bool.
  Extract Constant update_file => "Utils.update_file".

  Parameter delete_file : String.t -> t bool.
  Extract Constant delete_file => "Utils.delete_file".

  Parameter list_files : String.t -> t (option (list String.t)).
  Extract Constant list_files => "Utils.list_files".
End Lwt.

Definition list_posts (directory : LString.t)
  : Lwt.t (option (list Post.Header.t)) :=
  Lwt.bind (Lwt.list_files @@ String.of_lstring directory) (fun file_names =>
  Lwt.ret @@ file_names |> option_map (fun file_names =>
  let posts := file_names |> List.map (fun file_name =>
    Post.Header.of_file_name @@ String.to_lstring file_name) in
  (* We removed the elements `None`. *)
  List.fold_left (fun posts post =>
    match post with
    | None => posts
    | Some post => post :: posts
    end)
    posts [])).

Fixpoint eval {A : Type} (x : C.t A) : Lwt.t A :=
  match x with
  | C.Ret x => Lwt.ret x
  | C.Let (Command.ReadFile file_name) handler =>
    Lwt.bind (Lwt.read_file @@ String.of_lstring file_name) (fun content =>
    eval @@ handler @@ option_map String.to_lstring content)
  | C.Let (Command.UpdateFile file_name content) handler =>
    let file_name := String.of_lstring file_name in
    let content := String.of_lstring content in
    Lwt.bind (Lwt.update_file file_name content) (fun is_success =>
    eval @@ handler is_success)
  | C.Let (Command.DeleteFile file_name) handler =>
    Lwt.bind (Lwt.delete_file @@ String.of_lstring file_name) (fun is_success =>
    eval @@ handler is_success)
  | C.Let (Command.ListPosts directory) handler =>
    Lwt.bind (list_posts directory) (fun posts =>
    eval @@ handler posts)
  | C.Let (Command.Log message) handler =>
    let message := String.of_lstring message in
    Lwt.bind (Lwt.printl message) (fun _ =>
    eval @@ handler tt)
  end.

Parameter main_loop :
  (list String.t -> list (String.t * list String.t) -> list (String.t * String.t) ->
    Lwt.t (String.t * list (String.t * String.t) * String.t)) ->
  unit.
Extract Constant main_loop => "fun handler ->
  Lwt_main.run (Utils.start_server handler 8008)".

Definition main (handler : Http.Request.t -> C.t Http.Answer.t) : unit :=
  main_loop (fun path args cookies =>
    let path := List.map String.to_lstring path in
    let args := args |> List.map (fun (arg : _ * _) =>
      let (name, values) := arg in
      (String.to_lstring name, List.map String.to_lstring values)) in
    let cookies := cookies |> List.map (fun (cookie : _ * _) =>
      let (key, v) := cookie in
      (String.to_lstring key, String.to_lstring v)) in
    let request := Http.Request.Get path args cookies in
    Lwt.bind (eval @@ handler request) (fun answer =>
    let mime_type := String.of_lstring @@ View.mime_type answer in
    let content := String.of_lstring @@ View.content answer in
    let cookies := View.cookies answer |> List.map (fun (cookie : _ * _) =>
      let (key, v) := cookie in
      (String.of_lstring key, String.of_lstring v)) in
    Lwt.ret (mime_type, cookies, content))).
