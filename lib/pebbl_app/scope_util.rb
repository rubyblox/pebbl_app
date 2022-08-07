## PebblApp::ScopeUtil

require 'pebbl_app'

##  Utility Module for API Definitions
module PebblApp::ScopeUtil

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
  def svar_defined?(name, scope = nil)
    scope ||= self
    scope.singleton_class.instance_variable_defined?(name)
  end

  ## Return the effective value for an instance variable under the
  ## singleton class for the indicated scope
  ##
  ## @param name (see svar_defined)
  ## @param scope (see svar_defined)
  def svar_get(name, scope = nil)
    scope ||= self
    scope.singleton_class.instance_variable_get(name)
  end

  ## Set a value for an instance variable under the singleton class for
  ## the indicated scope
  ##
  ## @param name (see svar_defined)
  ## @param scope (see svar_defined)
  def svar_set(name, value, scope = nil)
    scope ||= self
    scope.singleton_class.instance_variable_set(name, value)
  end

  ## Set or return the value for an instance variable under the
  ## indicated scope
  ##
  ## @param name (see svar_defined)
  ## @param scope (see svar_defined)
  ## @param block [Proc] a block to evalute under the indicated scope. If
  ##  the instance variable has not been defined under the singleton
  ##  class for that scope, the instance variable's value will be set to
  ##  the value effectively returned by this block. The block will be
  ##  evaluated as with instance_eval for the indicated scope.
  def svar_bind(name, scope = nil, &block)
    name = name.to_sym
    scope ||= self
    if svar_defined?(name, scope)
      svar_get(name, scope)
    else
      value = scope.instance_eval(&block)
      svar_set(name, value, scope)
    end
  end

  ## Define a method under the singleton class for the provided scope
  ##
  ## @param name [Symbol] a method name, e.g. `:name`
  ## @param scope (see svar_defined)
  ## @param block [Proc] the block to provide for the method definition
  ##  under the singleton class for the indicated scope
  def smethod_define(name, scope = nil, &block)
    scope ||= self
    scope.singleton_class.define_method(name.to_sym, &block)
  end

  self.extend(self)
end
