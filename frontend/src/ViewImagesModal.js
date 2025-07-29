import React, { useState, useEffect } from "react";
import { Modal, ModalOverlay, ModalContent, ModalHeader, ModalCloseButton, ModalBody, VStack, Spinner, Box, Text, Image, Button, FormLabel, useToast } from "@chakra-ui/react";
import ImageUploadInput from "./ImageUploadInput";
import axios from "axios";
import { useParams, useNavigate, Link as RouterLink } from "react-router-dom";
export default function ViewImagesModal({ isOpen, onClose, item }) {
  const [images, setImages] = useState([]);
  const [imagesLoading, setImagesLoading] = useState(false);
  const [files, setFiles] = useState([]);
  const [filePreviews, setFilePreviews] = useState([]);
  const [removing, setRemoving] = useState(false);
  // Always use the latest item.meta_text when modal opens or item changes
  const [metaText, setMetaText] = useState("");
  const [metaTextLoading, setMetaTextLoading] = useState(false);
  const API_URL = process.env.REACT_APP_API_URL || "http://127.0.0.1:8000";
  const toast = useToast();

  useEffect(() => {
    if (!isOpen) {
      setImages([]);
      setFiles([]);
      setFilePreviews([]);
      setRemoving(false);
      setMetaText("");
      return;
    }
    if (item?.item_id) {
      setImagesLoading(true);
      axios.get(`${API_URL}/item_images/${item.item_id}`)
        .then(res => setImages(res.data.images || []))
        .catch(() => setImages([]))
        .finally(() => setImagesLoading(false));
      // Always update metaText from item prop
      setMetaText(item?.meta_text ?? "");
    }
  }, [isOpen, item, API_URL]);

  // Clean up previews
  useEffect(() => {
    return () => {
      filePreviews.forEach(url => URL.revokeObjectURL(url));
    };
  }, [filePreviews]);

  const handleDeleteImage = async (img) => {
    if (!item) return;
    let filename = img;
    if (typeof img === 'string' && img.includes('/')) {
      filename = img.split('/').pop().split('?')[0];
    }
    try {
      await axios.delete(`${API_URL}/item_image/${item.item_id}/${filename}`);
      setImages(images.filter(i => i !== img));
      toast({
        title: "Image deleted",
        description: "The image was successfully removed.",
        status: "success",
        duration: 3000,
        isClosable: true,
      });
    } catch {
      toast({
        title: "Error deleting image",
        description: "There was a problem removing the image.",
        status: "error",
        duration: 3000,
        isClosable: true,
      });
    }
  };

  const handleUpload = async () => {
    if (!item || files.length === 0) return;
    let success = true;
    for (let file of files) {
      const formData = new FormData();
      formData.append("item_id", item.item_id);
      formData.append("file", file);
      try {
        await axios.post(`${API_URL}/upload/`, formData);
      } catch {
        success = false;
      }
    }
    setFiles([]);
    setFilePreviews([]);
    // Refresh images
    setImagesLoading(true);
    axios.get(`${API_URL}/item_images/${item.item_id}`)
      .then(res => setImages(res.data.images || []))
      .catch(() => setImages([]))
      .finally(() => setImagesLoading(false));
    toast({
      title: success ? "Images uploaded" : "Upload error",
      description: success ? "Your images were added successfully." : "There was a problem uploading one or more images.",
      status: success ? "success" : "error",
      duration: 3000,
      isClosable: true,
    });
  };

  const handleRemoveItem = async () => {
    if (!item) return;
    setRemoving(true);
    await axios.delete(`${API_URL}/item/${item.item_id}`);
    setRemoving(false);
    if (typeof onClose === 'function') onClose();
  };

  const handleMetaTextUpdate = async () => {
    if (!item?.item_id) return;
    setMetaTextLoading(true);
    try {
      await axios.post(`${API_URL}/item/${item.item_id}/metadata`, metaText, {
        headers: { "Content-Type": "application/json" }
      });
      toast({ title: "Metadata updated", status: "success", duration: 2000, isClosable: true });
    } catch {
      toast({ title: "Failed to update metadata", status: "error", duration: 2000, isClosable: true });
    }
    setMetaTextLoading(false);
  };

  return (
    <Modal isOpen={isOpen && !!item} onClose={onClose} size="lg">
      <ModalOverlay />
      <ModalContent pb="1rem">
        <ModalHeader>
          Images for {item?.item_name}
          {item?.item_id && (
            <Text fontSize="sm" color="gray.400" mt={1} fontWeight="normal">
              ID: {item.item_id}
            </Text>
          )}
        </ModalHeader>
        <ModalCloseButton />
        <ModalBody>
          <Box mb={4}>
            <Button
              colorScheme="red"
              variant="outline"
              size="sm"
              onClick={() => {
                if (removing) return;
                if (window.confirm("Are you sure you want to delete this item and all its images? This action cannot be undone.")) {
                  handleRemoveItem();
                }
              }}
              isLoading={removing}
              loadingText="Removing..."
              mb={2}
            >
              Remove Item
            </Button>
          </Box>
          <Box mb={4}>
          <FormLabel>Metadata</FormLabel>
          <Box display="flex" gap={2} alignItems="center">
            <input
              type="text"
              value={metaText}
              onChange={e => setMetaText(e.target.value)}
              style={{ flex: 1, padding: "6px", borderRadius: "4px", border: "1px solid #ccc" }}
              disabled={metaTextLoading}
            />
            <Button
              colorScheme="blue"
              size="sm"
              onClick={handleMetaTextUpdate}
              isLoading={metaTextLoading}
            >Save</Button>
          </Box>
          </Box>
          {imagesLoading ? <Spinner /> : (
            <VStack align="start" spacing={2}>
              {images.map((img, idx) => (
                <Box key={idx} display="flex" alignItems="center">
                  <Image src={img} boxSize="120px" objectFit="cover" borderRadius="md" mr={2} />
                  <Button size="sm" colorScheme="red" onClick={() => handleDeleteImage(img)}>Delete</Button>
                </Box>
              ))}
              {images.length === 0 && <Text>No images found.</Text>}
              <Box mt={4} w="100%">
                <FormLabel>Add Images</FormLabel>
                <ImageUploadInput
                  id="add-images-upload"
                  multiple
                  onChange={e => {
                    const filesArr = Array.from(e.target.files);
                    setFiles(filesArr);
                    setFilePreviews(filesArr.map(file => URL.createObjectURL(file)));
                  }}
                  file={files.length > 0 ? files : null}
                  buttonLabel="Select Image"
                  changeLabel="Change Image"
                />
                {filePreviews.length > 0 && (
                  <Box display="flex" flexWrap="wrap" mt={2} mb={2} gap={2}>
                    {filePreviews.map((src, idx) => (
                      <Image key={idx} src={src} boxSize="60px" objectFit="cover" borderRadius="md" />
                    ))}
                  </Box>
                )}
                <Button colorScheme="blue" mt={2} onClick={handleUpload} isDisabled={files.length === 0}>Upload</Button>
              </Box>
            </VStack>
          )}
        </ModalBody>
      </ModalContent>
    </Modal>
  );
}
