require File.join(File.dirname(__FILE__), "..", "spec_helper")

describe "When recognizing requests," do

  describe "a namespaced route" do
    
    it "should add to the path and prepend the controller with the namespace" do
      Merb::Router.prepare do |r|
        r.namespace :admin do |admin|
          admin.match("/foo").to(:controller => "foos")
        end
      end
      route_to("/foo").should       have_nil_route
      route_to("/admin/foo").should have_route(:controller => "admin/foos")
    end
    
    it "should be able to prepend the namespace even if the :controller param has been specified already" do
      Merb::Router.prepare do |r|
        r.to(:controller => "bars") do |bars|
          bars.namespace(:admin) do |admin|
            admin.match!("/foo")
          end
        end
      end
      
      route_to("/admin/foo").should have_route(:controller => "admin/bars")
    end
    
    it "should be able to prepend the namespace even if :controller has been used in the path already" do
      Merb::Router.prepare do |r|
        r.match("/:controller") do |c|
          c.namespace(:marketing) do |marketing|
            marketing.to_route.register
          end
        end
      end
      
      route_to("/something/marketing").should have_route(:controller => "marketing/something")
    end
    
    it "should be able to specify the path prefix" do
      Merb::Router.prepare do |r|
        r.namespace :admin, :path => "administration" do |admin|
          admin.match("/foo").to(:controller => "foos")
        end
      end
      
      route_to("/admin/foo").should          have_nil_route
      route_to("/administration/foo").should have_route(:controller => "admin/foos")
    end
    
    it "should be able to set a namespace without a path prefix" do
      Merb::Router.prepare do |r|
        r.namespace :admin, :path => "" do |admin|
          admin.match("/foo").to(:controller => "foos")
        end
      end
      
      route_to("/admin/foo").should have_nil_route
      route_to("/foo").should have_route(:controller => "admin/foos")
    end
    
    it "should preserve previous conditions" do
      Merb::Router.prepare do |r|
        r.match :domain => "foo.com" do |foo|
          foo.namespace :admin do |admin|
            admin.match("/foo").to(:controller => "foos")
          end
        end
      end
      
      route_to("/admin/foo").should have_nil_route
      route_to("/admin/foo", :domain => "foo.com").should have_route(:controller => "admin/foos")
    end
    
    it "should preserve previous params" do
      Merb::Router.prepare do |r|
        r.to(:awesome => "true") do |awesome|
          awesome.namespace :administration do |a|
            a.match("/something").to(:controller => "home")
          end
        end
      end
      
      route_to("/administration/something").should have_route(:controller => "administration/home", :awesome => "true")
    end
    
    it "should preserve previous defaults" do
      Merb::Router.prepare do |r|
        r.defaults(:action => "awesome", :foo => "bar") do |foo|
          foo.namespace :baz do |baz|
            baz.match("/users").to(:controller => "users")
          end
        end
      end
      
      route_to("/baz/users").should have_route(:controller => "baz/users", :action => "awesome", :foo => "bar")
    end
    
    it "should be preserved through match blocks" do
      Merb::Router.prepare do |r|
        r.namespace(:admin) do |a|
          a.match(:domain => "admin.domain.com").to(:controller => "welcome")
        end
      end
      
      route_to("/admin", :domain => "admin.domain.com").should have_route(:controller => "admin/welcome")
    end
    
    it "should be preserved through to blocks" do
      Merb::Router.prepare do |r|
        r.namespace(:blah) do |blah|
          blah.to(:action => "overload") do |o|
            o.match("/blah").to(:controller => "weeeee")
          end
        end
      end
      
      route_to("/blah/blah").should have_route(:controller => "blah/weeeee", :action => "overload")
    end
    
    it "should be preserved through defaults blocks" do
      Merb::Router.prepare do |r|
        r.namespace(:blah) do |blah|
          blah.defaults(:action => "overload") do |o|
            o.match("/blah").to(:controller => "weeeee")
          end
        end
      end
      
      route_to("/blah/blah").should have_route(:controller => "blah/weeeee", :action => "overload")
    end
  end
  
  describe "a nested namespaced route" do
    it "should append the paths and controller namespaces together" do
      Merb::Router.prepare do |r|
        r.namespace(:foo) do |foo|
          foo.namespace(:bar) do |bar|
            bar.match("/blah").to(:controller => "weeeee")
          end
        end
      end
      
      route_to('/foo/bar/blah').should have_route(:controller => 'foo/bar/weeeee', :action => 'index')
    end
    
    it "should respec the custom path prefixes set on each namespace" do
      Merb::Router.prepare do |r|
        r.namespace(:foo, :path => "superfoo") do |foo|
          foo.namespace(:bar, :path => "superbar") do |bar|
            bar.match("/blah").to(:controller => "weeeee")
          end
        end
      end
      
      route_to('/superfoo/superbar/blah').should have_route(:controller => 'foo/bar/weeeee', :action => 'index')
    end
    
    it "should preserve previous conditions" do
      Merb::Router.prepare do |r|
        r.namespace(:foo) do |foo|
          foo.match(:protocol => 'https://') do |secure|
            secure.namespace(:bar) do |bar|
              bar.match("/blah").to(:controller => "weeeee")
            end
          end
        end
      end
      
      route_to('/foo/bar/blah', :protocol => 'https://').should have_route(:controller => 'foo/bar/weeeee', :action => 'index')
    end
    
    it "should preserve previous params" do
      Merb::Router.prepare do |r|
        r.namespace(:foo) do |foo|
          foo.match('/:first') do |first|
            first.namespace(:bar) do |bar|
              bar.match("/blah").to(:controller => "weeeee")
            end
          end
        end
      end
      
      route_to('/foo/one/bar/blah').should have_route(:controller => 'foo/bar/weeeee', :first => 'one', :action => 'index')
    end
    
    it "should preserve previous defaults" do
      Merb::Router.prepare do |r|
        r.namespace(:foo) do |foo|
          foo.defaults(:action => "megaweee") do |f|
            f.namespace(:bar) do |bar|
              bar.match("/blah").to(:controller => "weeeee")
            end
          end
        end
      end
      
      route_to('/foo/bar/blah').should have_route(:controller => 'foo/bar/weeeee', :action => 'megaweee')
    end
      
    it "should be preserved through match blocks" do
      Merb::Router.prepare do |r|
        r.namespace(:foo) do |foo|
          foo.match('/bar') do |bar|
            bar.namespace(:baz) do |baz|
              baz.match("/blah").to(:controller => "weeeee")
            end
          end
        end
      end
      
      route_to('/foo/bar/baz/blah').should have_route(:controller => 'foo/baz/weeeee')
    end
    
    it "should be preserved through to blocks" do
      Merb::Router.prepare do |r|
        r.namespace(:foo) do |foo|
          foo.match('/bar').to(:controller => 'bar') do |bar|
            bar.namespace(:baz) do |baz|
              baz.match("/blah").to(:action => "weeeee")
            end
          end
        end
      end
      
      route_to('/foo/bar/baz/blah').should have_route(:controller => 'foo/baz/bar', :action => "weeeee")
    end
    
    it "should be preserved through defaults blocks" do
      Merb::Router.prepare do |r|
        r.namespace(:foo) do |foo|
          foo.defaults(:action => "default_action") do |f|
            f.namespace(:baz) do |baz|
              baz.match("/blah").to(:controller => "blah")
            end
          end
        end
      end
      
      route_to('/foo/baz/blah').should have_route(:controller => 'foo/baz/blah', :action => "default_action")
    end
  end

  # I'm not sure if a) these are in the right spec file and b) if they are needed at all
  describe "a namespaced resource" do
    
    it "should match a get to /admin/foo/blogposts to the blogposts controller and index action" do
      Merb::Router.prepare do |r|
        r.namespace :admin do |admin|
          admin.resource :foo do |foo|
            foo.resources :blogposts
          end
        end
      end
      route_to('/admin/foo/blogposts', :method => :get).should have_route(:controller => 'admin/blogposts', :action => 'index', :id => nil)
    end

    it "should match a get to /admin/blogposts/1/foo to the foo controller and the show action" do
      Merb::Router.prepare do |r|
        r.namespace :admin do |admin|
          admin.resources :blogposts do |blogposts|
            blogposts.resource :foo
          end
        end
      end
      route_to('/admin/blogposts/1/foo', :method => :get).should have_route(:controller => 'admin/foo', :action => 'show', :blogpost_id => '1', :id => nil)
    end
  
    it "should match a get to /my_admin/blogposts to the blogposts controller with a custom patch setting" do
      Merb::Router.prepare do |r|
        r.namespace(:admin, :path => "my_admin") do |admin|
          admin.resources :blogposts
        end
      end
      route_to('/my_admin/blogposts', :method => :get).should have_route(:controller => 'admin/blogposts', :action => 'index', :id => nil)
    end

    it "should match a get to /admin/blogposts/1/foo to the foo controller and the show action with namespace admin" do
      Merb::Router.prepare do |r|
        r.namespace(:admin, :path => "") do |admin|
          admin.resources :blogposts do |blogposts|
            blogposts.resource :foo
          end
        end
      end
      
      route_to('/blogposts/1/foo', :method => :get).should have_route(:controller => 'admin/foo', :action => 'show', :blogpost_id => '1', :id => nil)
    end
  end

  describe "a nested namespaced resource" do
    it "should match a get to /admin/superadmin/blogposts to the blogposts controller and index action and a nested namespace" do
      Merb::Router.prepare do |r|
        r.namespace :admin do |admin|
          r.namespace :superadmin do |superadmin|
            admin.resources :blogposts
          end
        end
      end
      
      route_to('/admin/blogposts', :method => :get).should have_route(:controller => 'admin/blogposts', :action => 'index', :id => nil)
    end
  end
end