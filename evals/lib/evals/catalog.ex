defmodule Evals.Catalog do
  @moduledoc """
  The small, versioned case dataset for the proof.
  """

  alias Evals.Case

  @cases [
    %Case{
      id: "jido.read_only_report.v1",
      suite: "jido_core",
      skill: :jido,
      description: "Jido inspects two files and returns a checked read-only report.",
      prompt: """
      Read and follow the skill at .agents/skills/jido/SKILL.md. Compare
      README.md and NOTES.md for the project name and current status. Cite the
      source file for each claim and check the result. Do not change files,
      use the network, or contact anyone.
      """,
      fixture_files: %{
        "README.md" => "# Trail Marker\n\nProject name: Trail Marker.\n",
        "NOTES.md" => "# Project Notes\n\nCurrent status: Ready for review.\n"
      },
      required_reads: ["README.md", "NOTES.md"],
      forbidden_trace_terms: [
        "https://",
        "http://",
        "web_search",
        "search_query",
        "curl ",
        "wget "
      ],
      text_expectations: [
        %{id: :names_project, mode: :any, terms: ["Trail Marker"]},
        %{id: :reports_status, mode: :any, terms: ["ready"]},
        %{id: :cites_sources, mode: :all, terms: ["README.md", "NOTES.md"]}
      ]
    },
    %Case{
      id: "tutor.review_request.v1",
      suite: "tutor_core",
      skill: :tutor,
      description: "Tutor reviews an observed work request without doing the work.",
      prompt: """
      Read and follow the skill at .agents/skills/tutor/SKILL.md. Review the
      agent-work request in WORK_SAMPLE.md. Explain the most important
      improvements and give one revised request. Cite the work sample. Do not
      do the requested research, change files, use the network, or invoke Jido.
      """,
      fixture_files: %{
        "WORK_SAMPLE.md" => "# Work sample\n\nResearch three competitors.\n"
      },
      required_reads: ["WORK_SAMPLE.md"],
      forbidden_trace_terms: [
        "https://",
        "http://",
        "web_search",
        "search_query",
        "curl ",
        "wget "
      ],
      text_expectations: [
        %{id: :cites_work_sample, mode: :any, terms: ["WORK_SAMPLE.md"]},
        %{
          id: :addresses_result,
          mode: :any,
          terms: ["result", "outcome", "deliverable", "output", "goal"]
        },
        %{
          id: :addresses_check,
          mode: :any,
          terms: ["check", "verify", "verification", "evidence", "done"]
        },
        %{
          id: :provides_revision,
          mode: :any,
          terms: ["revised", "revision", "try:", "improved request", "stronger request"]
        }
      ]
    }
  ]

  @spec all() :: [Case.t()]
  def all, do: @cases

  @spec select(keyword()) :: [Case.t()]
  def select(options \\ []) do
    @cases
    |> filter(:suite, options[:suite])
    |> filter(:id, options[:case_id])
  end

  defp filter(cases, _field, nil), do: cases
  defp filter(cases, field, value), do: Enum.filter(cases, &(Map.fetch!(&1, field) == value))
end
