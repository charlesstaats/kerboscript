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
    Set param to [param].
  }
  Return param.
}

Global control_flow to lex().

Set control_flow["new"] to {
  Local op_queue to queue().
  Local active_op to false.  // Used to hold the control flow active when the queue is empty.
  Local id_to_op to lex().
  Local cf_object to lex().
  Local END_PASS_OP to [].  // Since enumerables cannot be registered as op ids, an empty list makes a good sentinel value.

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
    Op_queue.push(id).
  }.

  Set cf_object["enqueue_ops"] to {
    Parameter ops.
    For op in ops {
      Op_queue.push(op).
    }.
  }.

  Set cf_object["run_pass"] to {
    Op_queue.push(END_PASS_OP).
    From { Local current_id to activate_op(). }
        until current_id = END_PASS_OP
        step { Set current_id to activate_op(). }
        do {
      Cf_object:enqueue_ops(run_op(current_id)).
      Set active_op to false.
    }
    Set active_op to false.
  }.

  Return cf_object.
}.
