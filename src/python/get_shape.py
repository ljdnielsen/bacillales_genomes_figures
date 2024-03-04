import os
import csv
import sys
from Bio import SeqIO
from tqdm import tqdm

def extract_topology(file_path):
    topologies = []
    with open(file_path, 'r') as file:
        for record in SeqIO.parse(file, "genbank"):
            if 'topology' in record.annotations:
                topology = record.annotations['topology']
            else:
                topology = "Topology not specified"
            topologies.append((record.id, topology))
    return topologies

def process_folder(folder_path, output_file):
    with open(output_file, 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(['File', 'Record ID', 'Topology'])

        for filename in tqdm(os.listdir(folder_path)): # tqdm() supplies progress bar
            if filename.endswith('.gb') or filename.endswith('.gbk'):
                full_path = os.path.join(folder_path, filename)
                for record_id, topology in extract_topology(full_path):
                    writer.writerow([filename, record_id, topology])
        
if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python extract_topology.py <folder_path> <output_file>")
        sys.exit(1)
    
    folder_path = sys.argv[1]
    output_file = sys.argv[2]
    process_folder(folder_path, output_file)