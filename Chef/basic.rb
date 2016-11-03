package 'git' do
    action :install
end

package 'httpd' do
    action [:enable, :start]
end