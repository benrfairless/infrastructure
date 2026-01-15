#!/usr/bin/ruby

# Usage: ./rekey.rb > new.yaml; cp new.yaml group_vars/righttoknow.yaml

INFILE="group_vars/ec2.yml"
NEWID="ec2"

require 'yaml'

# Load YAML file with permitted classes for Ansible vault strings
data = YAML.safe_load_file(INFILE, permitted_classes: [], aliases: true)

data.each_pair do |key, value|
  if value =~ /.*ANSIBLE_VAULT.*/
    decrypted = `echo '#{value}' | ansible-vault decrypt`
    decrypted = decrypted.strip
    rekeyed = `echo -n '#{decrypted}' | ansible-vault --encrypt-vault-id #{NEWID} encrypt_string --stdin-name #{key}`
    $stdout.puts rekeyed
  else
    # Use gsub instead of gsub! to avoid mutation and nil return issues
    output = YAML.dump_stream({key => value}).gsub(/---\n/, "")
    $stdout.puts output
  end
end
