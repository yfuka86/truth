require 'minitest/autorun'
require 'minitest/unit'
require 'pry'

module World
  class Entity
    KINDOF_PROPOSITION = %i(atoms bottom negations disjunctions conjunctions conditionals)
    def initialize
      reset
    end

    def reset
      @truth = KINDOF_PROPOSITION.reduce({}) do |hash, k|
        hash[k] = []
        hash
      end
    end

    def <<(proposition)
      # TODO 同じものがあったときの判定はここでやる
      # TODO 可能態を作れるように。
      case proposition
      when Atom        then @truth[:atoms]         << proposition
      when Bottom      then @truth[:bottom]        << proposition
      when Negation    then @truth[:negations]     << proposition
      when Disjunction then @truth[:disjunctions]  << proposition
      when Conjunction then @truth[:conjunctions]  << proposition
      when Conditional then @truth[:conditionals]  << proposition
      end
    end

    def truth
      @truth
    end

    def propositions
      atoms + bottom + negations + disjunctions + conjunctions + conditionals
    end

    KINDOF_PROPOSITION.each do |sym|
      define_method sym do
        @truth[sym]
      end
    end
  end
end

$world = World::Entity.new

class Proposition
  BOTTOM_GIVE_ANY_PROPOSITION = -> (world) { true if world.bottom.count > 0 }

  def false?
    eval!.eql?(false)
  end

  def true?
    eval!.eql?(true)
  end

  def initialize
    @introduction_rules = []
    @elimination_rules = []
    @introduction_rules << BOTTOM_GIVE_ANY_PROPOSITION
  end

  def def!(world=$world)
    @elimination_rules.each do |proc|
      ary = proc.call(world)
      ary.each do |proposition|
        proposition.def!(world)
      end
    end
    world << self
  end

  def world_if_this_be_defined(base_world=$world)
    another_world = base_world.clone
    def! another_world
    another_world
  end

  def eval!(context=$world)
    if @introduction_rules.any?{ |proc| proc.call(context) == true }
      return true
    else
      return false
    end
  end
end

# P　原子論理式
# Atom.def!(:P)
class Atom < Proposition
  attr_accessor :pred

  def initialize(pred)
    super()
    @pred = pred

    @introduction_rules << -> (world) do
      world.atoms.any?{|atom| atom.pred == @pred}
    end
  end

  def equal?(proposition)
    @pred == proposition.pred
  end

  def propositions
    [self]
  end
end
Atm = Atom

class Propositional < Proposition
end

class Bottom < Propositional
  def initialize
    super
    @introduction_rules << -> (world) do
      world.negations.any?{|ng| ng.proposition.eval! }
    end
  end

  def def!(world=$world)
    if world.bottom.count > 0
      raise 'Bottom is already defined'
    else
      world << self
    end
  end
end

class PropositionalConnective < Propositional
end

# 否定
class Negation < PropositionalConnective
  attr_accessor :proposition

  def initialize(proposition)
    super()
    @proposition = proposition

    @introduction_rules << -> (world) do
      another_world = @proposition.world_if_this_be_defined(world)
      Bottom.new.eval!(another_world) == true
    end

    @elimination_rules << -> (world) do
      if @proposition.is_a? Negation
        [@proposition.proposition]
      else
        []
      end
    end
  end

  def equal?(proposition)
    return unless proposition.is_a? Negation
    @proposition.equal? proposition.proposition
  end

  def propositions
    @proposition.propositions << self
  end
end
Ng = Negation

# 論理積
class Conjunction < Proposition
  attr_accessor :proposition1, :proposition2

  def initialize(proposition1, proposition2)
    super()
    @proposition1, @proposition2 = proposition1, proposition2

    @introduction_rules << -> (world) do
      @proposition1.eval!(world) && @proposition2.eval!(world)
    end

    @elimination_rules << -> (world) do
      [@proposition1, @proposition2]
    end
  end

  def equal?(proposition)
    return false unless proposition.is_a? Conjunction
    (@proposition1.equal?(proposition.proposition1) && @proposition2.equal?(proposition.proposition2)) ||
    (@proposition1.equal?(proposition.proposition2) && @proposition2.equal?(proposition.proposition1))
  end

  def propositions
    @proposition1.propositions.concat @proposition2.propositions << self
  end
end
AND = Conjunction

# 論理和
class Disjunction < Proposition
  attr_accessor :proposition1, :proposition2

  def initialize(proposition1, proposition2)
    super()
    @proposition1, @proposition2 = proposition1, proposition2

    @introduction_rules << -> (world) do
      @proposition1.eval!(world) || @proposition2.eval!(world)
    end

    @elimination_rules << -> (world) do
      another_world = @proposition1.world_if_this_be_defined(world)
      another_world2 = @proposition2.world_if_this_be_defined(world)
      ary = []
      world.propositions.each do |proposition|
        ary << proposition if proposition.eval!(another_world) && proposition.eval!(another_world2)
      end
    end
  end

  def equal?(proposition)
    return false unless proposition.is_a? Disjunction
    (@proposition1.equal?(proposition.proposition1) && @proposition2.equal?(proposition.proposition2)) ||
    (@proposition1.equal?(proposition.proposition2) && @proposition2.equal?(proposition.proposition1))
  end

  def propositions
    @proposition1.propositions.concat @proposition2.propositions << self
  end
end
OR = Disjunction

class Conditional < Proposition
  attr_accessor :proposition1, :proposition2

  def initialize(proposition1, proposition2)
    super()
    @proposition1, @proposition2 = proposition1, proposition2

    @introduction_rules << -> (world) do
      another_world = @proposition1.world_if_this_be_defined(world)
      @proposition2.eval!(another_world)
    end

    @elimination_rules << -> (world) do
      if @proposition1.eval!(world)
        [@proposition2]
      else
        []
      end
    end
  end

  def equal?(proposition)
    return false unless proposition.is_a? Conditional
    (@proposition1.equal?(proposition.proposition1) && @proposition2.equal?(proposition.proposition2))
  end

  def propositions
    @proposition1.propositions.concat @proposition2.propositions << self
  end
end


class TestArray < MiniTest::Unit::TestCase
  def test_utils
    Disjunction.new(Atom.new(:p), Atom.new(:q)).def!
    Conditional.new(Atom.new(:p), Atom.new(:r)).def!
    Conditional.new(Atom.new(:q), Atom.new(:r)).def!
    assert_equal(true, Atom.new(:r).eval!)
    # Conditional.new(Atom.new(:p), Atom.new(:r)).def!
    # Conditional.new(Atom.new(:q), Negation.new(Atom.new(:r))).def!
    # assert_equal(true, Negation.new(Conjunction.new(Atom.new(:p), Atom.new(:q))).eval!)
  end
end

