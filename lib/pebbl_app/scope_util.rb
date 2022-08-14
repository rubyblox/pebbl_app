## PebblApp::ScopeUtil

require 'pebbl_app'

##  Utility Module for API Definitions
module PebblApp::ScopeUtil

  def instance_defined?(name, scope = nil)
    scope || self
    scope.instance_variable_defined?(name)
  end

  def instance_get(name, scope = nil)
    scope ||= self
    scope.instance_variable_get(name)
  end

  def instance_set(name, value, scope = nil)
    scope ||= self
    scope.instance_variable_set(name, value)
  end

  def instance_bind(name, scope = nil, &block)
    name = name.to_sym
    scope ||= self
    if instance_defined?(name, scope)
      instance_get(name, scope)
    else
      value = scope.instance_eval(&block)
      instance_set(name, value, scope)
    end
  end

  ## Return true if an instance variable is defined under the singleton
  ## class for the indicated scope, for the provided instance variable
  ## name.
  ##
  ## @param name [Symbol] an instance variable name, e.g. `:@name`
  ##
  ## @param scope [nil or Object] Indicator for the scope of the test.
  ##   If no literal scope value is provided or a value of `nil` or
  ##   `false` is provided, then this method will use the value of
  ##   `self` at the time of evaluation.
  ##
  ## @return [boolean] boolean value
  def singleton_defined?(name, scope = nil)
    scope ||= self
    instance_defined?(name, scope.singleton_class)
  end

  ## Return the effective value for an instance variable under the
  ## singleton class for the indicated scope
  ##
  ## @param name (see singleton_defined)
  ## @param scope (see singleton_defined)
  def singleton_get(name, scope = nil)
    scope ||= self
    instance_get(name, scope.singleton_class)
  end

  ## Set a value for an instance variable under the singleton class for
  ## the indicated scope
  ##
  ## @param name (see singleton_defined)
  ## @param scope (see singleton_defined)
  def singleton_set(name, value, scope = nil)
    scope ||= self
    instance_set(name, scope.singleton_class)
  end

  ## Set or return the value for an instance variable under the
  ## indicated scope
  ##
  ## @param name (see singleton_defined)
  ## @param scope (see singleton_defined)
  ## @param block [Proc] a block to evalute under the indicated scope. If
  ##  the instance variable has not been defined under the singleton
  ##  class for that scope, the instance variable's value will be set to
  ##  the value in effect returned by this block. The block will be
  ##  evaluated with instance_eval for the indicated scope.
  def singleton_bind(name, scope = nil, &block)
    name = name.to_sym
    scope ||= self
    if singleton_defined?(name, scope)
      singleton_get(name, scope)
    else
      value = scope.singleton_class.instance_eval(&block)
      singleton_set(name, value, scope)
    end
  end

  self.extend(self)
end
