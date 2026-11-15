defmodule Evals.Case do
  @moduledoc """
  One versioned skill evaluation case.

  A case contains its input, fixture, and deterministic expectations. It does
  not select a provider or model.
  """

  @enforce_keys [
    :id,
    :suite,
    :skill,
    :description,
    :prompt,
    :fixture_files,
    :required_reads,
    :forbidden_trace_terms,
    :text_expectations
  ]
  defstruct [
    :id,
    :suite,
    :skill,
    :description,
    :prompt,
    :fixture_files,
    :required_reads,
    :forbidden_trace_terms,
    :text_expectations
  ]

  @type text_expectation :: %{
          required(:id) => atom(),
          required(:mode) => :all | :any,
          required(:terms) => [String.t()]
        }

  @type t :: %__MODULE__{
          id: String.t(),
          suite: String.t(),
          skill: atom(),
          description: String.t(),
          prompt: String.t(),
          fixture_files: %{required(String.t()) => String.t()},
          required_reads: [String.t()],
          forbidden_trace_terms: [String.t()],
          text_expectations: [text_expectation()]
        }
end
