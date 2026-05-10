defmodule Cocktail.Util do
  @moduledoc false

  def next_gte([], _), do: nil
  def next_gte([x | rest], search), do: if(x >= search, do: x, else: next_gte(rest, search))

  def beginning_of_day(time) do
    time
    |> Timex.beginning_of_day()
    |> no_ms()
  end

  def beginning_of_month(time) do
    time
    |> Timex.beginning_of_month()
    |> no_ms()
  end

  def shift_time(datetime, opts) do
    datetime
    |> Timex.shift(opts)
    |> shift_dst(datetime)
    |> no_ms()
  end

  def no_ms(time) do
    Map.put(time, :microsecond, {0, 0})
  end

  # In case of datetime we may expect the same timezone hour
  # For example after daylight saving 10h MUST still 10h the next day.
  # This behaviour could only happen on datetime with timezone (that include `std_offset`)

  # Timex.shift/2 (with :months or :weeks) uses calendar arithmetic and returns
  # AmbiguousDateTime when the result lands in the DST fall-back window (e.g. 1:00 AM
  # on fall-back night exists in both EDT and EST). Pick the side whose std_offset matches
  # the original datetime so the wall-clock correction below computes to zero, preserving
  # the wall-clock hour unchanged.
  defp shift_dst(%Timex.AmbiguousDateTime{before: before_dt, after: after_dt}, datetime) do
    std_offset = Map.get(datetime, :std_offset, 0)
    resolved = if before_dt.std_offset == std_offset, do: before_dt, else: after_dt
    shift_dst(resolved, datetime)
  end

  defp shift_dst(time, datetime) do
    if offset = Map.get(datetime, :std_offset) do
      Timex.shift(time, seconds: offset - time.std_offset)
    else
      time
    end
  end
end
