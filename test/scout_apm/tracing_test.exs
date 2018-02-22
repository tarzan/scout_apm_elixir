defmodule ScoutApm.TracingTest do
  use ExUnit.Case, async: true
  setup do
    :code.delete(TracingAnnotationTestModule)
    :code.purge(TracingAnnotationTestModule)
    :ok
  end

  describe "@transaction" do
    test "automatic name" do
      [{TracingAnnotationTestModule, _}] = Code.compile_string(
      """
      defmodule TracingAnnotationTestModule do
        use ScoutApm.Tracing

        @transaction(type: "background")
        def bar do
          1
        end
      end
      """)
    end

    test "creates layers" do
      Code.eval_string(
      """
      defmodule TracingAnnotationTestModule do
        use ScoutApm.Tracing

        @transaction(type: "background")
        def bar do
          1
        end
      end
      """)

      assert TracingAnnotationTestModule.bar() == 1
      assert %ScoutApm.TrackedRequest{} = Process.get(:scout_apm_request)
    end

    test "creates layers on multiple" do
      Code.eval_string(
      """
      defmodule TracingAnnotationTestModule do
        use ScoutApm.Tracing

        @transaction(type: "background", name: "bar1")
        def bar(1) do
          1
        end

        @transaction(type: "background", name: "bar2")
        def bar(2) do
          2
        end

        @transaction(type: "background", name: "bar3")
        def bar(3) do
          3
        end
      end
      """)

      assert TracingAnnotationTestModule.bar(1) == 1
      assert TracingAnnotationTestModule.bar(2) == 2
      assert TracingAnnotationTestModule.bar(3) == 3
      assert %ScoutApm.TrackedRequest{root_layer: []} = Process.get(:scout_apm_request)
    end

    test "creates layers in GenServer handle_info/2" do
      Code.eval_string(
      """
      defmodule TracingAnnotationTestGenServer do
        use ScoutApm.Tracing
        use GenServer

        def start_link() do
          GenServer.start_link(__MODULE__, %{})
        end

        def init(_) do
          {:ok, %{}}
        end

        @transaction(type: "background", name: "handle_info/2")
        def handle_info(_, state) do
          :timer.sleep(100)
          {:noreply, state}
        end
      end
      """)

      {:ok, pid} = TracingAnnotationTestGenServer.start_link()
      assert send(pid, :hello)
      :timer.sleep(100)
      assert %ScoutApm.TrackedRequest{} = Process.get(:scout_apm_request)
    end

    test "explicit name" do
      [{TracingAnnotationTestModule, _}] = Code.compile_string(
      """
      defmodule TracingAnnotationTestModule do
        use ScoutApm.Tracing

        @transaction(type: "background", name: "It's just a test")
        def bar do
          1
        end
      end
      """)
    end

    test "several function clauses" do
      [{TracingAnnotationTestModule, _}] = Code.compile_string(
      """
      defmodule TracingAnnotationTestModule do
        use ScoutApm.Tracing

        @transaction(type: "background", name: "Uno")
        def bar(1) do
          1
        end

        @transaction(type: "background", name: "Dos")
        def bar(2) do
          2
        end

        @transaction(type: "background", name: "XXX")
        def bar(x) do
          x
        end
      end
      """)

      assert [
        {:transaction, :bar, [1]},
        {:transaction, :bar, [2]},
        {:transaction, :bar, [{:x, _, _}]}
      ] = TracingAnnotationTestModule.__info__(:attributes)[:scout_instrumented]
    end
  end

  describe "@timing" do
    test "automatic name" do
      [{TracingAnnotationTestModule, _}] = Code.compile_string(
      """
      defmodule TracingAnnotationTestModule do
        use ScoutApm.Tracing

        @timing(category: "Test")
        def bar do
          1
        end
      end
      """)
    end

    test "explicit name" do
      [{TracingAnnotationTestModule, _}] = Code.compile_string(
      """
      defmodule TracingAnnotationTestModule do
        use ScoutApm.Tracing

        @timing(category: "Test", name: "Bar")
        def bar do
          1
        end
      end
      """)
    end

    test "several function clauses" do
      [{TracingAnnotationTestModule, _}] = Code.compile_string(
      """
      defmodule TracingAnnotationTestModule do
        use ScoutApm.Tracing

        @timing(category: "Test", name: "barOne")
        def bar(1) do
          1
        end

        @timing(category: "Test", name: "barTwo")
        def bar(2) do
          2
        end

        @timing(category: "Test", name: "barXXX")
        def bar(x) do
          x
        end
      end
      """)

      assert [
        {:timing, :bar, [1]},
        {:timing, :bar, [2]},
        {:timing, :bar, [{:x, _, _}]}
      ] = TracingAnnotationTestModule.__info__(:attributes)[:scout_instrumented]
    end
  end

  describe "transaction block" do
    test "basic usage" do
      [{TracingAnnotationTestModule, _}] = Code.compile_string(
      """
      defmodule TracingAnnotationTestModule do
        use ScoutApm.Tracing

        def bar(1) do
          ScoutApm.Tracing.transaction(:web, "TracingMacro") do
            1
          end
        end
      end
      """)
    end

    test "creates layers" do
      Code.eval_string(
      """
      defmodule TracingAnnotationTestModule do
        use ScoutApm.Tracing

        def bar do
          ScoutApm.Tracing.transaction(:web, "TracingMacro") do
            1
          end
        end
      end
      """)

      assert TracingAnnotationTestModule.bar() == 1
      assert %ScoutApm.TrackedRequest{} = Process.get(:scout_apm_request)
    end

    # Note this lets you leave off the leading `ScoutApm.Tracing.` bit
    test "usage with import" do
      [{TracingAnnotationTestModule, _}] = Code.compile_string(
      """
      defmodule TracingAnnotationTestModule do
        import ScoutApm.Tracing

        def bar(1) do
          transaction(:web, "TracingMacro") do
            1
          end
        end
      end
      """)
    end
  end
end
