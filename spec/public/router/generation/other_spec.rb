require File.join(File.dirname(__FILE__), '..', "spec_helper")

describe "When generating URLs," do
  
  describe "a route with a Regexp path" do
    
    it "should not generate" do
      Merb::Router.prepare do |r|
        r.match(%r[/hello/world]).to.name(:regexp)
      end
      
      lambda { url(:regexp) }.should raise_error(Merb::Router::GenerationError)
    end
    
  end
  
end