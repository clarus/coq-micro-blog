Require Import ListString.All.
Require Http.
Require Import Model.

Module Raw.
  Record t := New {
    mime_type : LString.t;
    cookies : Http.Cookies.t;
    content : LString.t }.
End Raw.

Module Public.
  Inductive t :=
  | Index (posts : list Post.Header.t)
  | PostShow (url : LString.t) (post : option Post.t).
End Public.

Module Private.
  Inductive t :=
  | PostAdd
  | PostDoAdd (is_success : bool)
  | PostEdit (url : LString.t) (post : option Post.t)
  | PostDoEdit (url : LString.t) (is_success : bool)
  | PostDoDelete (is_success : bool).
End Private.

Inductive t :=
| NotFound | WrongArguments | Forbidden
| Static (mime_type : LString.t) (content : LString.t)
| Login | Logout
| Public (is_logged : bool) (page : Public.t)
| Private (page : Private.t).