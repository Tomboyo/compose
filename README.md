# Compose

In this project we define a control-flow macro which helps us unambiguously and distinctly handle error terms from a pipeline. Consider the following:

```elixir
with(
  {:ok, x} <- f(), # f :: {:ok, _} | :error
  {:ok, y} <- g()  # g :: {:ok, _} | :error
) do
  y + 1
else
  :error -> "Is this from f() or g()?"
end
```

This is presented as a control-flow problem: how do you perform a sequence of operations, each building upon the last, such that each possible cause of error is distinctly handled?

The `with` expression is not intended to solve for the control-flow problem above. To the contrary, `with` only composes pattern matches together into one larger expression whose type signature is a union of the values produced by its generators. Since many Elixir functions return the same error patterns `:error` and `{:error, term}`, its common for a `with` to also type as `v | :error | {:error, term}`. Whether we use two generators or a million, a composition of patterns generally devolves into two cases: it worked, or it didn't. In many situations this boolean outcome is desirable. For control flow, it is not.

Our `compose` macro is intended for the control-flow scenario. The following is a solution to the problem posed above:

```elixir
compose do
  {:ok, x} <- f()
  :error >>> "Error from f."

  {:ok, y} <- g()
  :error >>> "Error from g."

  y + 1
end
```

Here we have two pattern-matched generator functions written using `<-` operators with the same meaning as in `with`. We also have two error-value match expressions written using `>>>` operators, with a similar meaning as the `->` expressions in `with`. Here, if a generator fails to match, the error-value may be matched by one of the subsequent and consecutive `>>>` expressions. That is, if `f()` produces an error value, it may match the first `>>>` expression, but never the second. If the error value is not handled, we raise an error.