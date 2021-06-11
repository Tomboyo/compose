defmodule Compose do
  @match :<-
  @error :>>>

  defmacro compose(do: {_, _, clauses}) do
    {return_clause, clauses} = List.pop_at(clauses, -1)

    chunked =
      clauses
      |> with_index()
      |> Enum.group_by(fn {_i, {k, _, _}} -> k end)

    matches =
      chunked[@match]
      |> Enum.map(fn {i, {_, _, [lhs, rhs]}} ->
        {:<-, [], [{i, lhs}, {i, rhs}]}
      end)
    
    errors =
      chunked[@error]
      |> Enum.map(fn {i, {_, _, [lhs, rhs]}} ->
        {:->, [], [[{i, lhs}], rhs]}
      end)

    quote do
      with(unquote_splicing(matches), [do: unquote(return_clause), else: [unquote_splicing(errors)]])
    end
  end

  # Index expressions such that the index groups together consecutive @match expressions and
  # subsequent consecutive @error expressions. The index advances per group. For example, a series
  # of expressions match, match, ..., match, error, error, ..., error are indexed together. A
  # subsequent match would advance the index (whereas a subsequent error would not).
  defp with_index(xs, acc \\ [], i \\ 0, prev \\ nil) do
    if xs == [] do
      Enum.reverse(acc)
    else
      [x | tail] = xs
      {sym, _, _} = x

      case {sym, prev} do
        {@error, nil} -> raise "Expected at least one #{@match} clause before the first #{@error} clause"
        {@match, nil} -> with_index(tail, [{i, x} | acc], i, sym)
        {@match, @match} -> with_index(tail, [{i, x} | acc], i, sym)
        {@error, @match} -> with_index(tail, [{i, x} | acc], i, sym)
        {@error, @error} -> with_index(tail, [{i, x} | acc], i, sym)
        {@match, @error} -> with_index(tail, [{i + 1, x} | acc], i + 1, sym)
      end
    end
  end
end
