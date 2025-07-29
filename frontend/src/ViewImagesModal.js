import React, { useState, useEffect } from "react";
import { Modal, ModalOverlay, ModalContent, ModalHeader, ModalCloseButton, ModalBody, VStack, Spinner, Box, Text, Image, Button, FormLabel } from "@chakra-ui/react";
import ImageUploadInput from "./ImageUploadInput";

export default function ViewImagesModal({
  isOpen,
  onClose,
  item,
  images,
  imagesLoading,
  onDeleteImage,
  files,
  setFiles,
  filePreviews,
  setFilePreviews,
  onUpload,
  onRemoveItem
}) {
  const [removing, setRemoving] = useState(false);
  // Reset removing state when modal closes
  useEffect(() => {
    if (!isOpen) setRemoving(false);
  }, [isOpen]);

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
                  setRemoving(true);
                  if (typeof onRemoveItem === 'function') {
                    onRemoveItem(item?.item_id);
                  }
                }
              }}
              isLoading={removing}
              loadingText="Removing..."
              mb={2}
            >
              Remove Item
            </Button>
          </Box>
          {imagesLoading ? <Spinner /> : (
            <VStack align="start" spacing={2}>
              {images.map((img, idx) => (
                <Box key={idx} display="flex" alignItems="center">
                  <Image src={img} boxSize="120px" objectFit="cover" borderRadius="md" mr={2} />
                  <Button size="sm" colorScheme="red" onClick={() => onDeleteImage(img)}>Delete</Button>
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
                <Button colorScheme="blue" mt={2} onClick={onUpload} isDisabled={files.length === 0}>Upload</Button>
              </Box>
            </VStack>
          )}
        </ModalBody>
      </ModalContent>
    </Modal>
  );
}
