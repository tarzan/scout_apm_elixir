defmodule ScoutApm.MetricSet do
  @moduledoc """
  A way to absorb & combine metrics into a single set, keeping track of min/max/count, etc.

  While this is just a map underneath, treat it like an opaque data type.
  """

  def new do
    %{}
  end

  def absorb(metric_set, type, name, time) do
    key = "#{type}/#{name}"

    Map.update(metric_set, key,
               new_metric(type, name, time),
               fn metric -> update_metric(metric, time) end
              )
  end

  # Ditches the key part, and just returns the aggregate metric
  def to_list(metric_set) do
    metric_set
    |> Map.to_list
    |> Enum.map(fn {_,x} -> x end)
  end

  #####################
  #  Private Helpers  #
  #####################

  defp new_metric(type, name, time) do
    %{
      type: type,
      name: name,

      call_count: 1,
      total_call_time: time,
      total_exclusive_time: time,
      min_call_time: time,
      max_call_time: time
    }
  end

  defp update_metric(metric, time) do
    %{
      metric |
      call_count: metric[:call_count] + 1,
      total_call_time: metric[:total_call_time] + time,
      total_exclusive_time: metric[:total_exclusive_time] + time,
      min_call_time: Enum.min([metric[:min_call_time], time]),
      max_call_time: Enum.max([metric[:max_call_time], time]),
    }
  end
end
