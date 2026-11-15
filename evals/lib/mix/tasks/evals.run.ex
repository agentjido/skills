defmodule Mix.Tasks.Evals.Run do
  use Mix.Task

  @shortdoc "List or run the small Jido and Tutor evaluation proof"

  @switches [
    list: :boolean,
    provider: :string,
    model: :string,
    reasoning_effort: :string,
    suite: :string,
    case: :string,
    timeout: :integer
  ]

  @impl true
  def run(args) do
    {options, positional, invalid} = OptionParser.parse(args, strict: @switches)

    if invalid != [] or positional != [] do
      usage!()
    end

    if options[:list] do
      list_cases(options)
    else
      run_cases(options)
    end
  end

  defp list_cases(options) do
    cases = Evals.cases(suite: options[:suite], case_id: options[:case])

    if cases == [] do
      Mix.raise("no evaluation cases matched")
    end

    Enum.each(cases, fn eval_case ->
      Mix.shell().info(
        "#{eval_case.suite}\t#{eval_case.id}\t#{eval_case.skill}\t#{eval_case.description}"
      )
    end)
  end

  defp run_cases(options) do
    provider = options[:provider] || usage!()
    provider = parse_provider!(provider)
    reasoning_effort = parse_reasoning_effort!(options[:reasoning_effort])
    timeout_ms = Keyword.get(options, :timeout, 300) * 1_000

    Mix.Task.run("app.start")

    run_options = [
      model: options[:model],
      reasoning_effort: reasoning_effort,
      suite: options[:suite],
      case_id: options[:case],
      timeout_ms: timeout_ms
    ]

    case Evals.run(provider, run_options) do
      {:ok, report} ->
        print_report(report)

        unless report.summary.failed == 0,
          do: Mix.raise("one or more skill evaluation cases failed")

      {:error, reason} ->
        Mix.raise("skill evaluation could not run: #{inspect(reason)}")
    end
  end

  defp print_report(report) do
    Mix.shell().info("provider: #{report.provider}")
    Mix.shell().info("model: #{report.model || "provider default"}")
    Mix.shell().info("reasoning: #{report.reasoning_effort || "provider default"}")

    Enum.each(report.measurements, fn measurement ->
      Mix.shell().info("\n#{measurement.case.id} (#{measurement.case.skill})")

      Enum.each(measurement.metrics.results, fn metric ->
        Mix.shell().info("#{if(metric.passed?, do: "PASS", else: "FAIL")} #{metric.id}")
      end)

      Mix.shell().info(measurement.observation.text)
    end)

    Mix.shell().info(
      "\nsummary: #{report.summary.passed}/#{report.summary.case_count} cases passed, " <>
        "mean score #{Float.round(report.summary.mean_score, 3)}"
    )

    Mix.shell().info("report: #{report.report_path}")
  end

  defp parse_provider!(name) do
    provider =
      Jido.Harness.providers()
      |> Enum.map(& &1.provider)
      |> Enum.find(&(Atom.to_string(&1) == name))

    provider || Mix.raise("unknown provider: #{name}")
  end

  defp parse_reasoning_effort!(nil), do: nil
  defp parse_reasoning_effort!("low"), do: :low
  defp parse_reasoning_effort!("medium"), do: :medium
  defp parse_reasoning_effort!("high"), do: :high
  defp parse_reasoning_effort!("xhigh"), do: :xhigh

  defp parse_reasoning_effort!(value) do
    Mix.raise("reasoning effort must be low, medium, high, or xhigh; got: #{value}")
  end

  defp usage! do
    Mix.raise("""
    usage:
      mix evals.run --list [--suite SUITE] [--case CASE_ID]
      mix evals.run --provider PROVIDER [--model MODEL] [--reasoning-effort LEVEL]
                    [--suite SUITE] [--case CASE_ID] [--timeout SECONDS]
    """)
  end
end
