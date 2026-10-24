% Jack Billington and Jacob Karam 
% CSCI 431 - Project 01 
% Trail Marker Detector


function project_1_main

    % the directory
    imageDir = "ADK_Images_Batch_B/";

    % read in all of the images from the batch
    imageFiles = dir(fullfile(imageDir, '*.jpg'));
    
    % array to store all of the 'correctly' classified images
    valid_images = {};

    % loop through all images and preproccess them
    for i = 1:length(imageFiles)

        % path to the images
        path = fullfile(imageFiles(i).folder, imageFiles(i).name);
        % the image
        image = imread(path);

        % Pre proccess time
        [im, flag] = preProccessImages(image, path);

        % if the flag is true, then the image is valid and add it to the
        % array of valid images
        if flag
            valid_images{end+1} = im;
        end

    end

    % loop over the valid images to find the circles in them
    for ii = 1:length(valid_images)
        
        % the current image
        curr_img = valid_images{ii};

        % create our yellow mask to find the markers
        mask = yellowMask(curr_img);
    
        % find the circles using hough detection
        [centers, radii] = imfindcircles(mask, [60 200], 'Sensitivity', 0.9, ...
            'EdgeThreshold', 0.05);
    
        % plot the preproccessed image
        figure(); 
        subplot(1, 2, 1);
        imshow(curr_img);
        title("Preproccessed Image");

        % plot the image with the circles
        subplot(1, 2, 2);
        imshow(curr_img); 
        hold on;
        if ~isempty(centers)
            viscircles(centers, radii, 'Color',[1, 0.5, 0],'LineWidth',4);
            title("Markers Found")
        else
            title('No markers found');
        end
        
    end

end


% This function takes in an image and preprocesses it. It determines
% whether or not
% 
% Params:
%       - image: the image we are manipulating
%       - filename: the filename of the image to check the metadata
%
% Returns:
%       - image: the pre processed image
%       - flag: a boolean to see if the image is bad or not
function [image, flag] = preProccessImages(image, filename)
    
    % flag to see if the image is valid and should be included
    flag = 1;

    % First step: correct the image orientation

    % Get the metadata of the image to see if it is rotated
    info = imfinfo(filename);
    orientation = info.Orientation;
   
    % Use a switch case to see what orientation the image is in a correct
    % it. 
    % Orientation:
    % 1 = upright
    % 3 = rotated 180 degrees
    % 6 = rotated 270 degrees
    % 8 = rotated 90 degrees
    switch orientation
        case 1
            img_rot = image; 
        case 3
            img_rot = imrotate(image, 180);
        case 6
            img_rot = imrotate(image, -90); 
        case 8
            img_rot = imrotate(image, 90);
        otherwise
            img_rot = image; 
    end

    % set back to image for sanity
    image = img_rot;

    % check to see if the image is over or underexposed based on the mean
    % of all pixel values
    gray_image = rgb2gray(image);
    gray_image = im2double(gray_image);
    avg_num_pixels = mean(gray_image, "all");
    
    % if it is not properly exposed, throw it away
    if ((avg_num_pixels < 0.35) || (avg_num_pixels > 0.55))
        flag = 0;
    end

    % check to see if the image has edges
    laplacian = fspecial('laplacian', 0);
    laplacian_img = imfilter(gray_image, laplacian, 'same', 'repl');
    variance_laplacian = var(laplacian_img(:));

    % if not then deem the image as blurry and throw it away
    % NOTE: HDR images do not seem to work very well with our code so they
    % will also be thrown out by this
    if variance_laplacian < 0.0099
        flag = 0;
    end

    % Normalize the exposure of each image

    % Convert the image to LAB
    image_lab = rgb2lab(image);

    % Separate the L, A, and B channels
    L = image_lab(:, :, 1);
    A = image_lab(:, :, 2);
    B = image_lab(:, :, 3);

    % histogram equalization on the Luminance channel
    L_eq = adapthisteq(L / 100) * 100;
    % Recombine the channels
    image_lab_eq = cat(3, L_eq, A, B); 

    % Convert back to RGB
    image = lab2rgb(image_lab_eq); 
    
    % Thrid Step: Use a smoothing filter to smooth the image
    image = imbilatfilt(image, 2);


end


% This function creates a mask of the input image where there is yellow.
% Basically it makes everything thay is yellow, white, and everything else
% black. The goal is to find the circular trail markers
% 
% Params:
%       - im: the image we are manipulating
%
% Returns:
%       - mask: the computed mask
function mask = yellowMask(im)

    % convert that thang to double
    im = im2double(im);

    % convert to LAB for yellow/blue channel
    lab = rgb2lab(im);
    A = lab(:,:,2);
    B = lab(:,:,3);

    % get all that good stuff with this threshold 
    mask = B > 45 & (A > -15 & A < 35);

    % clean mask
    mask = imclose(mask, strel('disk',8));  
    mask = imfill(mask, 'holes'); 
    mask = imopen(mask, strel('disk',6));  
    mask = bwareaopen(mask, 3000);

end
