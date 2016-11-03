# basic.rb
# Teaching the basics of Chef using Chef-DK
package 'git' do
    action :install
end

package 'httpd' do
    action [:enable, :start]
end