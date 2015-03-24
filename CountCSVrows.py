#########################################
# Count total number of rows in CSV file
#########################################

import csv
import sys

# FOLLOWING CODE FROM:
# http://stackoverflow.com/questions/15063936/csv-error-field-larger-than-field-limit-131072

# Used to increase the field size 

maxInt = sys.maxsize
decrement = True

while decrement:
    # decrease the maxInt value by factor 10 
    # as long as the OverflowError occurs.

    decrement = False
    try:
        csv.field_size_limit(maxInt)
    except OverflowError:
        maxInt = int(maxInt/10)
        decrement = True


# COUNT TOTAL ROWS/ENTRIES IN CSV FILE
# NOTES:
#   1. reader reads in first data entry
#   2. Encoding parameter eliminates UNICODEDECODEERROR
#   3. Rows include column heading -> Total Entries = Total Rows - 1

with open("donorschoose-org-17feb2012-v1-essays.csv",
          'rt', encoding = 'latin1') as f:
    
    reader = csv.reader(f, delimiter=",")

    totalrows = 0
    totalentries = 0
    
    for row in reader:
        if totalrows== 1:
            #print (row)
            totalrows+=1

    if totalrows == -1:
        totalentries = 0
        
    else:
        totalentries = totalrows - 1

    print ("Total Data Entries:", totalentries)



    
