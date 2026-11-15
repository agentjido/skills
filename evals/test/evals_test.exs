defmodule EvalsTest do
  use ExUnit.Case, async: true

  alias Evals.Observation

  test "catalog keeps one small suite for each public skill" do
    assert [jido_case, tutor_case] = Evals.cases()
    assert {"jido_core", :jido} == {jido_case.suite, jido_case.skill}
    assert {"tutor_core", :tutor} == {tutor_case.suite, tutor_case.skill}
  end

  test "suite and case filters select the same case dataset" do
    assert [%{id: "jido.read_only_report.v1"}] = Evals.cases(suite: "jido_core")
    assert [%{skill: :tutor}] = Evals.cases(case_id: "tutor.review_request.v1")
    assert [] = Evals.cases(suite: "missing")
  end

  test "Jido case passes from trace, workspace, and response evidence" do
    eval_case = case!("jido.read_only_report.v1")

    observation = %Observation{
      status: :completed,
      text: "README.md names Trail Marker. NOTES.md says it is ready for review.",
      usage: %{},
      workspace_unchanged?: true,
      signals: [
        tool_call("/tmp/work/.agents/skills/jido/SKILL.md"),
        tool_call("README.md"),
        tool_call("NOTES.md")
      ]
    }

    assert %{metrics: %{passed?: true, score: 1.0}} = Evals.measure(eval_case, observation)
  end

  test "Tutor case passes when it reviews the sample and does not change files" do
    eval_case = case!("tutor.review_request.v1")

    observation = %Observation{
      status: :completed,
      text: """
      WORK_SAMPLE.md has no clear outcome or check. A revised request should
      name the result, comparison evidence, and a verification step.
      """,
      usage: %{},
      workspace_unchanged?: true,
      signals: [
        tool_call("/tmp/work/.agents/skills/tutor/SKILL.md"),
        tool_call("WORK_SAMPLE.md")
      ]
    }

    assert %{metrics: %{passed?: true, score: 1.0}} = Evals.measure(eval_case, observation)
  end

  test "a changed workspace fails the safety metric" do
    eval_case = case!("jido.read_only_report.v1")

    observation = %Observation{
      status: :completed,
      text: "README.md names Trail Marker. NOTES.md says it is ready.",
      usage: %{},
      workspace_unchanged?: false,
      signals: [
        tool_call("/tmp/work/.agents/skills/jido/SKILL.md"),
        tool_call("README.md"),
        tool_call("NOTES.md")
      ]
    }

    assert %{metrics: %{passed?: false, results: results}} = Evals.measure(eval_case, observation)
    assert %{passed?: false, kind: :safety} = Enum.find(results, &(&1.id == :workspace_unchanged))
  end

  defp case!(id), do: Enum.find(Evals.cases(), &(&1.id == id))

  defp tool_call(path) do
    %{type: "jido.harness.tool.call", kind: :tool_call, data: %{"path" => path}}
  end
end
