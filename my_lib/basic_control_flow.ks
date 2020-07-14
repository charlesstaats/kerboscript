@LAZYGLOBAL OFF.

Local function assert {
  Parameter valid.
  Parameter error_message.
  If not valid {
    Print error_message.
    Print 1/0.
  }
}

Local function to_enumerable {
  Parameter param.
  If not param:istype("enumerable") {
    Set param to list(param).
  }
  Return param.
}

Global control_flow to lex().

Set control_flow["merge"] to {
  Parameter sequence_id.
  Local retv to lex().
  Set retv["merging_sequence"] to sequence_id.
  Return retv.
}.

Set control_flow["fork"] to {
  Parameter op_id.
  Parameter sequence_ops to list().
  Set sequence_ops to to_enumerable(sequence_ops).
  Local retv to lex().
  Set retv["forking_op"] to op_id.
  If sequence_ops:length > 0 {
    Set retv["forking_seq"] to sequence_ops.
  }.
  Return retv.
}.

Set control_flow["waitForSecs"] to {
  Parameter waiting_time.
  Parameter op_id is list().
  Local repeat to true.
  Local exit to false.
  If not op_id:hasSuffix("length") or op_id:length > 0 {
    Set repeat to op_id.
    Set exit to list().
  }.
  Local ending_time to -1.
  Return {
    If ending_time < 0 {
      Set ending_time to time:seconds + waiting_time.
      Return repeat.
    }.
    If time:seconds >= ending_time {
      Return exit.
    }
    Return repeat.
  }.
}.

Set control_flow["waituntil_then"] to {
  Parameter until_clause, do_clause.
  Parameter name is list().
  Local repeat to true.
  Local exit to false.
  If not name:hasSuffix("length") or name:length > 0 {
    Set repeat to name.
    Set exit to list().
  }.
  Return {
    If not until_clause() { Return repeat. }.
    Do_clause().
    Return exit.
  }.
}.

Set control_flow["new"] to {
  Parameter has_background_cf is true.

  Local op_queue to queue().
  Local active_op to false.  // Used to hold the control flow active when the queue is empty.
  Local id_to_op to lex().
  Local cf_object to lex().
  Local END_PASS_OP to list().  // Since enumerables cannot be registered as op ids, an empty list makes a good sentinel value.
  Local completed_sequences to UniqueSet().

  Set cf_object["sequence_done"] to {
    Parameter id.
    Return completed_sequences:contains(id).
  }.

  Set cf_object["register_op"] to {
    Parameter id.
    Parameter execute.

    Assert(not id:istype("enumerable"), "Attempted to use enumerable type " + id:typename + " as an id for a control flow op. This is not allowed.").

    Set id_to_op[id] to execute.
  }.

  Local run_op to {
    Parameter id.
    Local op to id_to_op[id].
    Local next_ops to to_enumerable(op()).
    Return next_ops.
  }.

  Local activate_op to {
    Assert(op_queue:length > 0, "Attempted to activate next op when op queue is empty.").
    Assert(not active_op, "Attempted to activate next op when an op is already active.").
    Set active_op to true.
    Return op_queue:pop().
  }.

  Set cf_object["active"] to {
    Return active_op or op_queue:length > 0.
  }.

  Set cf_object["enqueue_op"] to {
    Parameter id.
    Assert(not id:istype("enumerable"), "Attempted to enqueue enumerable type " + id:typename + " as an id for a control flow op. This is not allowed.").
    Op_queue:push(id).
  }.

  Set cf_object["register_and_enqueue_op"] to {
    Parameter id.
    Parameter execute.
    Cf_object:register_op(id, execute).
    Cf_object:enqueue_op(id).
  }.
    
  Set cf_object["register_and_enqueue_seq"] to {
    Parameter id.
    Parameter ops.
    Cf_object:register_sequence(id, ops).
    Cf_object:enqueue_op(id).
  }.

  Set cf_object["print_queue"] to {
    Print op_queue.
    If has_background_cf {
      Print "background:".
      Cf_object:background:print_queue().
    }.
  }.

  Set cf_object["enqueue_ops"] to {
    Parameter ops.
    For op in ops {
      Op_queue:push(op).
    }.
  }.

  If has_background_cf {
    Set cf_object["background"] to control_flow:new(false).  // Don't create background:background to avoid infinite recursion.
  }.

  Set cf_object["run_pass"] to {
    If has_background_cf {
      Cf_object:background:run_pass().
    }.
    Op_queue:push(END_PASS_OP).
    From { Local current_id to activate_op(). }
        until current_id = END_PASS_OP
        step { Set current_id to activate_op(). }
        do {
      Cf_object:enqueue_ops(run_op(current_id)).
      Set active_op to false.
    }
    Set active_op to false.
  }.

  Set cf_object["register_sequence"] to {
    Parameter id.
    Parameter ops.
    Parameter next_ops is list().


    Local cf to control_flow:new().

    {
      Local iter to ops:iterator.
      Until not iter:next() {
        Local i to iter:index.
        Local f to iter:value.
        If f:hassuffix("merging_sequence") {
          Cf:register_op(i, {
            If completed_sequences:contains(f:merging_sequence) {
              Return i + 1.
            } else {
              Return i.
            }
          }).
        } else if f:hassuffix("forking_op") {
          If f:hassuffix("forking_seq") {
            If f:forking_seq:length = 1 {
              Cf_object:register_op(f:forking_op, {
                If f:forking_seq[0]() {
                  Return f:forking_op.
                } else {
                  Return list().
                }.
              }).
            } else {
              Cf_object:register_sequence(f:forking_op, f:forking_seq).
            }.
          }.
          Cf:register_op(i, {
            Cf_object:enqueue_op(f:forking_op).
            Return i + 1.
          }).
        } else {
          Cf:register_op(i, {
            If f() { Return i. } else { Return i + 1. }.
          }).
        }
      }
    }
    Local return_value to 0.
    {
      Local i to ops:length.
      If next_ops:istype("KOSDelegate") {
        Cf:register_op(i, {
          Set return_value to next_ops().
          Return list().
        }).
      } else {
        Set return_value to next_ops.
        Cf:register_op(i, { Return list(). }).
      }
    }
    Cf:enqueue_op(0).

    Cf_object:register_op(id, {
      Cf:run_pass().
      If cf:active() {
        Return id.
      } else {
        Completed_sequences:add(id).
        Return return_value.
      }
    }).
  }.

  Return cf_object.
}.

