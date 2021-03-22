import os

mydir = "/data2/TORGO/" # change to your TORGO directory location

for subdir, dirs, files in os.walk(mydir):
    for file in files:
        filepath = subdir + os.sep + file
        
        if filepath.endswith(".wav"):
            name = filepath.split('/')
            ID = name[-4]
            SESS = name[-3][-1]
            MIC = name[-2].split('_')[1][:-3]
            WAV = name[-1] 
            
            new_name = ID + '_' + SESS + '_' + MIC + '_' + WAV
            #print(new_name)
            new_filepath = subdir + os.sep + new_name
            os.rename(filepath, new_filepath)
