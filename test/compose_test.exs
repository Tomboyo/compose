defmodule ComposeTest do
  use ExUnit.Case
  doctest Compose

  import Compose

  defp unused(_), do: raise "The subject will not call this function"

  def subject(f, g) do
    compose do
      {:ok, t} <- f.()
      :error >>> :f_error
      {:error, _cause} >>> :f_error_with_cause

      {:ok, u} <- g.(t)
      :error >>> :g_error
      {:error, _cause} >>> :g_error_with_cause
      nil >>> nil

      {:ok, u}
    end
  end

  test "If all patterns match, the final clause is the return value" do
    f = fn -> {:ok, 1} end
    g = fn x -> {:ok, x + 1} end

    assert subject(f, g) == {:ok, 2}
  end

  describe "When f.() does not match" do
    test "the :error arm may handle the error" do
      f = fn -> :error end
      g = &unused/1

      assert subject(f, g) == :f_error
    end

    test "the {:error, _cause} arm may handle the error" do
      f = fn -> {:error, nil} end
      g = &unused/1

      assert subject(f, g) == :f_error_with_cause
    end

    test "no arm after the match against g(t) may handle the error" do
      f = fn -> nil end
      g = &unused/1

      # Even though there is a `nil >>>` arm, it comes after the next match (with `g.(t)`) and
      # therefore may not handle the error. As a result, a WithClauseError will raise to indicate
      # that the nil could not be matched.
      assert_raise WithClauseError, fn ->
        subject(f, g)
      end
    end
  end

  describe "When g.(t) does not match" do
    test "the :error arm following g.(t) may handle the error" do
      f = fn -> {:ok, 1} end
      g = fn _ -> :error end
      
      # Note that the :error handler following f.() is skipped.
      assert subject(f, g) == :g_error
    end

    test "the {:error, _cause} arm following g.(t) may handle the error" do
      f = fn -> {:ok, 1} end
      g = fn _ -> {:error, nil} end

      # Note that the {:error, _cause} handler following f.() is skipped.
      assert subject(f, g) == :g_error_with_cause
    end

    test "the unmatched value may raise" do
      f = fn -> {:ok, 1} end
      g = fn _ -> :unmatchable end

      assert_raise WithClauseError, fn ->
        subject(f, g)
      end
    end
  end
end
