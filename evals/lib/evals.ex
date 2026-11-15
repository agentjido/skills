defmodule Evals do
  @moduledoc """
  Runs the small Jido and Tutor skill evaluation proof through Jido.Harness.
  """

  alias Evals.{Case, Catalog, Metrics, Observation}
  alias Jido.Harness.{RunResult, Signal}

  @default_timeout_ms 300_000
  @schema "jido-skill-evals/v1"

  @spec cases(keyword()) :: [Case.t()]
  def cases(options \\ []), do: Catalog.select(options)

  @spec run(atom(), keyword()) :: {:ok, map()} | {:error, term()}
  def run(provider, options \\ []) when is_atom(provider) do
    selected_cases = cases(options)

    if selected_cases == [] do
      {:error, :no_matching_cases}
    else
      started_at = DateTime.utc_now()

      with {:ok, measurements} <- run_cases(provider, selected_cases, options) do
        report = build_batch(provider, options, started_at, measurements)
        path = save_report!(report)
        {:ok, Map.put(report, :report_path, path)}
      end
    end
  end

  @spec measure(Case.t(), Observation.t()) :: map()
  def measure(%Case{} = eval_case, %Observation{} = observation) do
    %{
      case: case_summary(eval_case),
      observation: observation,
      metrics: Metrics.grade(eval_case, observation)
    }
  end

  defp run_cases(provider, cases, options) do
    Enum.reduce_while(cases, {:ok, []}, fn eval_case, {:ok, measurements} ->
      case run_case(provider, eval_case, options) do
        {:ok, measurement} -> {:cont, {:ok, [measurement | measurements]}}
        {:error, reason} -> {:halt, {:error, {eval_case.id, reason}}}
      end
    end)
    |> case do
      {:ok, measurements} -> {:ok, Enum.reverse(measurements)}
      error -> error
    end
  end

  defp run_case(provider, eval_case, options) do
    timeout_ms = Keyword.get(options, :timeout_ms, @default_timeout_ms)
    skills_root = Keyword.get(options, :skills_root, default_skills_root())
    skill_root = Path.join(skills_root, Atom.to_string(eval_case.skill))
    workspace = make_workspace!(eval_case, skill_root)
    before = workspace_snapshot!(workspace)

    try do
      request =
        %{
          prompt: eval_case.prompt,
          cwd: workspace,
          runtime_timeout_ms: timeout_ms,
          metadata: %{
            eval_case: eval_case.id,
            eval_suite: eval_case.suite,
            eval_skill: Atom.to_string(eval_case.skill)
          }
        }
        |> maybe_put(:model, options[:model])
        |> maybe_put(:reasoning_effort, options[:reasoning_effort])

      case Jido.Harness.run(provider, request, await_timeout: timeout_ms + 20_000) do
        {:ok, %RunResult{} = result} ->
          observation = observation(result, before == workspace_snapshot!(workspace))

          measurement =
            eval_case
            |> measure(observation)
            |> put_in([:case, :skill_digest], skill_digest!(skill_root))

          {:ok, measurement}

        {:error, reason} ->
          {:error, reason}
      end
    after
      File.rm_rf!(workspace)
    end
  end

  defp observation(result, workspace_unchanged?) do
    %Observation{
      status: result.status,
      text: result.text,
      usage: result.usage,
      workspace_unchanged?: workspace_unchanged?,
      signals: Enum.map(result.signals, &signal_row/1)
    }
  end

  defp signal_row(signal) do
    %{
      type: signal.type,
      kind: Signal.kind(signal),
      data: signal.data
    }
  end

  defp build_batch(provider, options, started_at, measurements) do
    passed = Enum.count(measurements, & &1.metrics.passed?)
    scores = Enum.map(measurements, & &1.metrics.score)

    %{
      schema: @schema,
      started_at: started_at,
      completed_at: DateTime.utc_now(),
      provider: provider,
      model: options[:model],
      reasoning_effort: options[:reasoning_effort],
      measurements: measurements,
      summary: %{
        case_count: length(measurements),
        passed: passed,
        failed: length(measurements) - passed,
        mean_score: Enum.sum(scores) / length(scores)
      }
    }
  end

  defp case_summary(eval_case) do
    %{
      id: eval_case.id,
      suite: eval_case.suite,
      skill: eval_case.skill,
      description: eval_case.description,
      prompt: eval_case.prompt
    }
  end

  defp make_workspace!(eval_case, skill_root) do
    unless File.regular?(Path.join(skill_root, "SKILL.md")) do
      raise ArgumentError, "skill not found at #{skill_root}"
    end

    workspace =
      Path.join(System.tmp_dir!(), "skill-eval-#{System.unique_integer([:positive])}")

    skill_target = Path.join([workspace, ".agents", "skills", Atom.to_string(eval_case.skill)])
    File.mkdir_p!(Path.dirname(skill_target))
    File.cp_r!(skill_root, skill_target)

    Enum.each(eval_case.fixture_files, fn {name, content} ->
      path = Path.join(workspace, name)
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, content)
    end)

    workspace
  end

  defp workspace_snapshot!(workspace) do
    workspace
    |> Path.join("**/*")
    |> Path.wildcard(match_dot: true)
    |> Enum.reject(&File.dir?/1)
    |> Enum.reject(&hidden_path?(&1, workspace))
    |> Map.new(fn path ->
      relative = Path.relative_to(path, workspace)
      digest = :crypto.hash(:sha256, File.read!(path)) |> Base.encode16(case: :lower)
      {relative, digest}
    end)
  end

  defp hidden_path?(path, workspace) do
    path
    |> Path.relative_to(workspace)
    |> Path.split()
    |> Enum.any?(&String.starts_with?(&1, "."))
  end

  defp skill_digest!(skill_root) do
    skill_root
    |> Path.join("**/*")
    |> Path.wildcard()
    |> Enum.reject(&File.dir?/1)
    |> Enum.sort()
    |> Enum.map(fn path -> [Path.relative_to(path, skill_root), 0, File.read!(path), 0] end)
    |> IO.iodata_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp save_report!(report) do
    timestamp =
      report.completed_at
      |> DateTime.to_iso8601()
      |> String.replace(~r/[^0-9A-Za-z.-]/, "-")

    directory = Path.expand("results", File.cwd!())
    path = Path.join(directory, "#{timestamp}-#{report.provider}.json")
    File.mkdir_p!(directory)
    File.write!(path, Jason.encode!(json_safe(report), pretty: true))
    path
  end

  defp json_safe(%_{} = value), do: value |> Map.from_struct() |> json_safe()

  defp json_safe(value) when is_map(value) do
    Map.new(value, fn {key, item} -> {to_string(key), json_safe(item)} end)
  end

  defp json_safe(value) when is_list(value), do: Enum.map(value, &json_safe/1)
  defp json_safe(value) when is_tuple(value), do: value |> Tuple.to_list() |> json_safe()
  defp json_safe(value) when is_boolean(value) or is_nil(value), do: value
  defp json_safe(value) when is_atom(value), do: Atom.to_string(value)
  defp json_safe(value), do: value

  defp default_skills_root, do: Path.expand("../skills", File.cwd!())

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
