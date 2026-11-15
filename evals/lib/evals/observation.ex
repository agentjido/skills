defmodule Evals.Observation do
  @moduledoc """
  Normalized evidence from one case run.
  """

  @enforce_keys [:status, :text, :usage, :workspace_unchanged?, :signals]
  defstruct [:status, :text, :usage, :workspace_unchanged?, :signals]

  @type signal_row :: %{
          required(:kind) => atom() | nil,
          required(:type) => String.t(),
          required(:data) => term()
        }

  @type t :: %__MODULE__{
          status: atom(),
          text: String.t(),
          usage: map(),
          workspace_unchanged?: boolean(),
          signals: [signal_row()]
        }
end
