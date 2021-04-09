// ---------------------------------------------
// Lamella in-silico Clearing (LisC) Algorithm
// ---------------------------------------------

// Felix JB Bäuerlein
// Version 1.0
// 16.Mar 2021

print("\\Clear");
print("-------------------------------------")
print("Lamella in-silico Clearing (LisC) Algorithm")
print("-------------------------------------")
print("Felix JB Bäuerlein et al., 2021")
print("Version 1.0")
print("")


// Dialog box: ask for Pixel Size
beep();    
Dialog.create("Lamella in silico Clearing Algorithm");
Dialog.addNumber("Pixel Size (nm):", 0.0);
Dialog.addNumber("High-pass Filter threshold (nm):", 5000);
Dialog.addCheckbox("Save intermediate files", false);
Dialog.addCheckbox("Close intermediate files", true);
Dialog.show();
OPS = Dialog.getNumber();
filter_thr_nm = Dialog.getNumber();
save_files = Dialog.getCheckbox();
close_files = Dialog.getCheckbox();

// Set parameters
filter_thr = round(filter_thr_nm/OPS);
sigma_masks = 6.5/OPS;
sigma_gray = filter_thr;

print("Used parameters:")
print("Object pixel size: " + OPS + " nm");
print("Filter threshold: " + filter_thr_nm + " nm (= " + filter_thr + " px)");
print("")
if (OPS==0) {exit("The pixel size cannot be 0 !! Please provide a value.")};

getDateAndTime(year, month, dayOfWeek, dayOfMonth, h_start, min_start, second_start, msec);
StartTime ="Started at: ";
if (h_start<10) {StartTime = StartTime+"0";}
StartTime = StartTime+h_start+":";
if (min_start<10) {StartTime = StartTime+"0";}
StartTime = StartTime+min_start+":";
if (second_start<10) {StartTime = StartTime+"0";}
StartTime = StartTime+second_start;
print(StartTime);

// ----- Preparation of masks for contamination and vacuum -----

// High-pass filter Original
rename("Original");
run("8-bit");
run("Duplicate...", " ");
rename("High-Pass Filtered");
run("Tile"); 
run("Bandpass Filter...", "filter_large=filter_thr filter_small=1 suppress=None tolerance=95");

// make vacuum mask
selectWindow("Original");
run("Duplicate...", " ");
rename("Mask_Vacuum_inv");
run("Gaussian Blur...", "sigma=sigma_masks");
run("Measure");
mean = getResult("Mean",0);
std = getResult("StdDev",0);
Thr = mean + 1.5*std;
setMinAndMax(Thr, Thr);

// make contamination mask
selectWindow("High-Pass Filtered");
run("Duplicate...", " ");
rename("Mask_Contamination_inv");
run("Gaussian Blur...", "sigma=sigma_masks");
run("Measure");
mean = getResult("Mean",0);
std = getResult("StdDev",0);
Thr = mean - 1.5*std;
setMinAndMax(Thr, Thr);
run("Clear Results");
run("Tile"); //run("Cascade");
run("Brightness/Contrast...");

// wait for userinteraction: mask optimization
 beep();
 title = "Check the Masks";
  msg = "Adapt the histogram for the Vacuum and the Contamination masks - click for each mask on \"Apply\"  - then after click \"OK\".";
  waitForUser(title, msg);


// process contamination mask
selectWindow("Mask_Contamination_inv");
//run("Convert to Mask");
run("Dilate"); run("Dilate");
run("Dilate"); run("Dilate");
run("Divide...", "value=255");
setMinAndMax(0, 1);
run("Duplicate...", " ");
rename("One");
run("Set...", "value=1");
imageCalculator("Subtract create", "One","Mask_Contamination_inv");
rename("Mask_Contamination");
setMinAndMax(0, 1);
close("One");

// process vacuum mask
selectWindow("Mask_Vacuum_inv");
//run("Convert to Mask");
run("Dilate"); run("Dilate");
run("Dilate"); run("Dilate");
run("Divide...", "value=255");
setMinAndMax(0, 1);
run("Duplicate...", " ");
rename("One");
run("Set...", "value=1");
setMinAndMax(0, 1);
imageCalculator("Subtract create", "One","Mask_Vacuum_inv");
rename("Mask_Vacuum");
setMinAndMax(0, 1);
close("One");

run("Tile"); //run("Cascade");


// create a local gray scale average map
selectWindow("High-Pass Filtered");
run("Duplicate...", " ");
run("Gaussian Blur...", "sigma=sigma_gray");
rename("Local_gray_scale_average");

// set pixel values of contamination to local gray scale average
imageCalculator("Multiply create", "Local_gray_scale_average","Mask_Contamination");
rename("Mask_Contamination_gray");
imageCalculator("Multiply create", "High-Pass Filtered","Mask_Contamination_inv");
rename("High-Pass Filtered_masked");
imageCalculator("Add", "High-Pass Filtered_masked","Mask_Contamination_gray");

// set pixel values of vacuum to local gray scale average
selectWindow("High-Pass Filtered_masked");
imageCalculator("Multiply", "High-Pass Filtered_masked","Mask_Vacuum");
imageCalculator("Multiply create", "Local_gray_scale_average","Mask_Vacuum_inv");
rename("Mask_Vacuum_gray");
imageCalculator("Add", "High-Pass Filtered_masked","Mask_Vacuum_gray");
run("Duplicate...", " ");
rename("Cleared_Image");

run("Tile"); //run("Cascade");


// ---------- Filtering of masked and high-pass filtered image  ----------

// remove horizontal curtains in Fourier Space 
selectWindow("Cleared_Image");
run("Bandpass Filter...", "filter_large=filter_thr filter_small=1 suppress=Horizontal tolerance=95");
//run("Bandpass Filter...", "filter_large=filter_thr filter_small=1 suppress=Vertical tolerance=80");


// set pixel values of vacuum to 255
imageCalculator("Multiply", "Cleared_Image","Mask_Vacuum");
selectWindow("Mask_Vacuum_inv");
run("Multiply...", "value=255");
imageCalculator("Add", "Cleared_Image","Mask_Vacuum_inv");

// set pixel values of contamination to zero
imageCalculator("Multiply", "Cleared_Image","Mask_Contamination_inv");
selectWindow("Cleared_Image");
run("Duplicate...", " ");
rename("Cleared_Image_bin2");
run("Bin...", "x=2 y=2 bin=Median"); // Binning 2x with Median


// Save all images to directory (if selected)
dir = "empty";
if (save_files ==true) {
	dir = getDirectory("Choose a Directory");
	print("Following files were saved:");
for (i=0;i<nImages;i++) {
        selectImage(i+1);
        title = getTitle;
        print(title);
        saveAs("tiff", dir+title);} 
// Close Intermediate data files
if (close_files ==true) {
selectWindow("Mask_Contamination.tif"); close();
selectWindow("Mask_Contamination_inv.tif"); close();
selectWindow("Mask_Contamination_gray.tif"); close();
selectWindow("Mask_Vacuum.tif"); close();
selectWindow("Mask_Vacuum_inv.tif"); close();
selectWindow("Mask_Vacuum_gray.tif"); close();
selectWindow("Local_gray_scale_average.tif"); close();
selectWindow("High-Pass Filtered.tif"); close();
selectWindow("High-Pass Filtered_masked.tif"); close(); }
	print("Intermediate Files saved!");
} 

else {
// Close Intermediate data files
if (close_files ==true) {
selectWindow("Mask_Contamination"); close();
selectWindow("Mask_Contamination_inv"); close();
selectWindow("Mask_Contamination_gray"); close();
selectWindow("Mask_Vacuum"); close();
selectWindow("Mask_Vacuum_inv"); close();
selectWindow("Mask_Vacuum_gray"); close();
selectWindow("Local_gray_scale_average"); close();
selectWindow("High-Pass Filtered"); close();
selectWindow("High-Pass Filtered_masked"); close();
}
print("Intermediate Files not saved...");
}

run("Tile");

// Time-stamp for Log
MonthNames = newArray("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
DayNames = newArray("Sun", "Mon","Tue","Wed","Thu","Fri","Sat");
getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
TimeString ="Date: "+DayNames[dayOfWeek]+" ";
if (dayOfMonth<10) {TimeString = TimeString+"0";}
TimeString = TimeString+dayOfMonth+"-"+MonthNames[month]+"-"+year+"\nTime: ";
if (hour<10) {TimeString = TimeString+"0";}
TimeString = TimeString+hour+":";
if (minute<10) {TimeString = TimeString+"0";}
TimeString = TimeString+minute+":";
if (second<10) {TimeString = TimeString+"0";}
TimeString = TimeString+second;

print(TimeString);

// Save Cleared and Original as .png (for smaller file size)
if (dir =="empty") {
	dir = getDirectory("Choose a Directory");
	}
for (i=0;i<nImages;i++) {
        selectImage(i+1);
        title = getTitle;
        print(title);
        saveAs("tiff", dir+title);
        saveAs("png", dir+title);
} 

// save log window
selectWindow("Log");  //select Log-window 
saveAs("Text", dir+"LisC_Filter_Log.txt"); 